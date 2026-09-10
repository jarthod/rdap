require 'json'
require 'net/http'
require 'ipaddr'

module RDAP
  VERSION = "1.0.1"
  BOOTSTRAP = "https://rdap.org/"
  TYPES = [:domain, :ip, :autnum].freeze
  HEADERS = {
    "User-Agent" => "RDAP ruby gem (#{VERSION})",
    "Accept" => "application/rdap+json, application/json, */*;q=0.8",
    # Had to include other types here because rdap.nic.fr returns an error with only rdap+json -_-
  }

  class Error < StandardError; end
  class ServerError < Error; end
  class SSLError < ServerError; end
  class ConnectionError < ServerError; end
  class EmptyResponse < ServerError; end
  class InvalidResponse < ServerError; end
  class NotFound < Error; end
  class TooManyRequests < Error; end

  def self.domain name, server: nil, **opts
    tld = name.to_s.chomp('.').split('.').last
    server ||= dns_index[tld.downcase] if tld
    query name, type: :domain, server: server, **opts
  end

  def self.ip name, server: nil, **opts
    ip = IPAddr.new(name.to_s)
    server ||= ip_index(ip.ipv6? ? 'ipv6' : 'ipv4').find { |net, _| net.include?(ip) }&.last
    query name, type: :ip, server: server, **opts
  end

  def self.as name, server: nil, **opts
    asn = name.to_i if name.is_a?(Integer) || name.to_s =~ /\A\d+\z/
    raise ArgumentError.new("RDAP: Invalid AS number: #{name.inspect}") unless asn
    server ||= asn_index.find { |range, _| range.cover?(asn) }&.last
    query name, type: :autnum, server: server, **opts
  end

  def self.query name, type:, timeout: 5, server: nil, headers: {}
    TYPES.include?(type) or raise ArgumentError.new("RDAP: Invalid query type: #{type}, supported types: #{TYPES}")
    # .domain/.ip/.as resolve the authoritative server from the bundled IANA
    # files; fall back to the public bootstrap server for anything not covered.
    server ||= BOOTSTRAP
    uri = URI("#{server.chomp('/')}/#{type}/#{name}")
    get_follow_redirects(uri, timeout: timeout, headers: headers)
  end

  private

  # TLD => RDAP server, built once for O(1) domain lookups. IANA lists the
  # preferred (https) endpoint first, so urls.first is the server to use.
  def self.dns_index
    @dns_index ||= bootstrap('dns').each_with_object({}) do |(labels, urls), index|
      labels.each { |label| index[label.downcase] = urls.first }
    end
  end

  # [network, RDAP server] pairs for a registry, built once so the CIDRs are
  # parsed into IPAddr objects a single time rather than on every lookup.
  def self.ip_index registry
    (@ip_index ||= {})[registry] ||= bootstrap(registry).flat_map do |cidrs, urls|
      cidrs.map { |cidr| [IPAddr.new(cidr), urls.first] }
    end
  end

  # [AS range, RDAP server] pairs, built once so the ranges are parsed a single
  # time rather than on every lookup.
  def self.asn_index
    @asn_index ||= bootstrap('asn').flat_map do |ranges, urls|
      ranges.map { |range| low, high = range.split('-'); [(low.to_i..(high || low).to_i), urls.first] }
    end
  end

  # Service entries from a bundled IANA bootstrap file (https://data.iana.org/rdap/).
  def self.bootstrap registry
    JSON.parse(File.read(File.expand_path("../data/#{registry}.json", __dir__)))["services"]
  end

  def self.get_follow_redirects uri, timeout: 5, headers: {}, redirection_limit: 5
    raise ServerError.new("Too many redirections (> #{redirection_limit}) at #{uri}") if redirection_limit == 0

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response = http.get(uri.path, HEADERS.merge(headers))
    case response
    when Net::HTTPSuccess
      if !response.body
        raise EmptyResponse.new("[#{response.code}] #{response.message}")
      end
      document = JSON.parse(response.body)
      if document["errorCode"]
        raise ServerError.new("[#{document["errorCode"]}] #{document["title"]} (#{uri})")
      end
      document
    when Net::HTTPNotFound
      # 404 sometimes return details in the JSON body so we threat them later
      if response.body.size > 0 and (document = JSON.parse(response.body) rescue nil)
        raise NotFound.new("[#{document["errorCode"]}] #{document["title"]}")
      else
        raise NotFound.new("[#{response.code}] #{response.message}")
      end
    when Net::HTTPTooManyRequests
      raise TooManyRequests.new("[#{response.code}] #{response.message}")
    when Net::HTTPRedirection
      get_follow_redirects(URI(response["location"]), timeout: timeout, headers: headers, redirection_limit: redirection_limit - 1)
    else
      raise ServerError.new("[#{response.code}] #{response.message}")
    end
  rescue OpenSSL::SSL::SSLError => e
    raise SSLError.new("#{e.message} (#{uri.host})")
  rescue JSON::ParserError => e
    raise InvalidResponse.new("JSON parser error: #{e.message}")
  rescue Timeout::Error, IOError, SocketError, SystemCallError => e
    # Transport failures (timeouts, DNS, connection reset/refused, EOF, ...)
    raise ConnectionError.new("#{e.class}: #{e.message} (#{uri.host})")
  end
end
