require 'json'
require 'net/http'

module RDAP
  VERSION = "0.1.0"
  BOOTSTRAP = "https://rdap.org/"
  TYPES = [:domain, :ip, :autnum]

  class Error < StandardError; end
  class ServerError < Error; end
  class NotFound < Error; end

  def self.domain name, **opts
    query name, type: :domain, **opts
  end

  def self.ip name, **opts
    query name, type: :ip, **opts
  end

  def self.as name, **opts
    query name, type: :autnum, **opts
  end

  def self.query name, type:, timeout: 5, server: BOOTSTRAP
    TYPES.include?(type) or raise ArgumentError.new("RDAP: Invalid query type: #{type}, supported types: #{TYPES}")
    uri = URI("#{server.chomp('/')}/#{type}/#{name}")
    get_follow_redirects(uri, timeout: timeout)
  end

  private

  def self.get_follow_redirects uri, timeout: 5, redirection_limit: 5
    raise ServerError.new("Too many redirections (> #{redirection_limit}) at #{uri}") if redirection_limit == 0

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response = http.get(uri.path, "Accept" => "application/rdap+json")
    case response
    when Net::HTTPSuccess
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
    when Net::HTTPRedirection
      get_follow_redirects(URI(response["location"]), timeout: timeout, redirection_limit: redirection_limit - 1)
    else
      raise ServerError.new("[#{response.code}] #{response.message}")
    end
  end
end
