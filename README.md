# RDAP

A minimal Ruby client to query RDAP APIs.
No runtime dependencies. It bundles the [IANA bootstrap files](https://data.iana.org/rdap/) so it can query the authoritative RDAP server directly, only falling back to a public bootstrap server for objects not yet covered.

[RDAP](https://en.wikipedia.org/wiki/Registration_Data_Access_Protocol) is a new protocol destined to replace WHOIS to query informations about domains, IPs, ASNs, etc.
Not all TLDs support RDAP at the moment, but the deployment is going well: https://deployment.rdap.org

Because queries go straight to the authoritative RDAP servers, this library no longer relies on a public bootstrap server for most queries and is suitable for higher volumes. Three things to keep in mind:
- individual RDAP servers may still enforce their own rate limits;
- queries for TLDs not yet present in the bundled files fall back to a public bootstrap server (which [enforces some throttling](https://about.rdap.org/#rate-limits)).
- you'll want to update the gem every now and then, if you use an old version of the gem you may get slower results (more reliance on bootstrap server) or request failures (if the RDAP server changed since bundled in your installed gem). If you can't, then you better always use a bootstrap server.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rdap'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rdap

## Usage

You can use `bin/console` from this repository for an interactive prompt.

```ruby
RDAP.domain("google.com")
# => {"objectClassName"=>"domain",
#  "handle"=>"2138514_DOMAIN_COM-VRSN",
#  "ldhName"=>"GOOGLE.COM",
#  "links"=>[...],
#  "status"=>[...],
#  "entities"=>[...],
#  "events"=>
#   [{"eventAction"=>"registration", "eventDate"=>"1997-09-15T04:00:00Z"},
#    {"eventAction"=>"expiration", "eventDate"=>"2028-09-14T04:00:00Z"},
#    {"eventAction"=>"last update of RDAP database", "eventDate"=>"2021-12-17T11:35:32Z"}],
#  "secureDNS"=>{"delegationSigned"=>false},
#  "nameservers"=>
#   [{"objectClassName"=>"nameserver", "ldhName"=>"NS1.GOOGLE.COM"},
#    {"objectClassName"=>"nameserver", "ldhName"=>"NS2.GOOGLE.COM"},
#    {"objectClassName"=>"nameserver", "ldhName"=>"NS3.GOOGLE.COM"},
#    {"objectClassName"=>"nameserver", "ldhName"=>"NS4.GOOGLE.COM"}],
#  "rdapConformance"=>
#   ["rdap_level_0", "icann_rdap_technical_implementation_guide_0", "icann_rdap_response_profile_0"],
#  "notices"=>[...]}
RDAP.ip("8.8.8.8") # IPv4
RDAP.ip("2620:119:35::35") # or IPv6
RDAP.as("16276") # AS Number ("autnum" in RDAP phraseology)

# there is also a lower level method accepting a type (:domain, :ip, :autnum) if needed, this one does not take into account IANA boostrap files, so you'll have to provide the server or rely on the default bootstrap server.
RDAP.query("16276", type: :autnum)

# Options
RDAP.domain("google.com", server: "https://rdap-bootstrap.arin.net/bootstrap") # Specify an alternative bootstrap server
RDAP.domain("google.com", server: "https://rdap.verisign.com/com/v1") # Or directly the target RDAP server if you know it
RDAP.domain("google.com", timeout: 20) # Customize open and read timeouts (default = 5 sec each)
RDAP.domain("google.com", headers: {'User-Agent' => 'My application name'}) # Override some HTTP request headers. Default headers are in RDAP::HEADERS

# Error handling
RDAP.domain("jsiqpmcurt.design") # Domain not found
# => RDAP::NotFound ([404] Not found)
RDAP.as("not-a-number") # Invalid AS number
# => ArgumentError (RDAP: Invalid AS number: "not-a-number")
RDAP.ip("not-an-ip") # Invalid IP address
# => IPAddr::InvalidAddressError (invalid address: not-an-ip)
RDAP.domain("u$&~(!*@&@^#}") # Invalid URI
# => URI::InvalidURIError (bad URI (is not URI?): "https://rdap.org/domain/u$&~(!*@&@^#}")
RDAP.domain("broken") # Other type of unexpected server response
# => RDAP::ServerError ([500] Internal Server Error)
```

## How does it work

The gem bundles the [IANA bootstrap files](https://data.iana.org/rdap/) (in `data/*.json`) and uses them to resolve the authoritative RDAP server for the requested domain, IP or ASN, then queries that server directly and returns the parsed JSON. This avoids routing every request through a public bootstrap server.

If the object isn't covered by the bundled files (for example a brand new TLD that hasn't been added yet), the query falls back to a public bootstrap server (https://rdap.org/ by default), whose responsibility is to check the bootstrap files and redirect to the proper RDAP server. You can also force a specific server (bootstrap or authoritative) with the `server:` option — for example ARIN runs its own bootstrap server at https://rdap-bootstrap.arin.net/bootstrap.

The bundled files are refreshed with `rake bootstrap:update` (maintainers do this before a release).

## Changelog

- **1.0.0** (2026-06-27) - Query the authoritative RDAP server directly using the bundled IANA bootstrap files, only falling back to the public bootstrap server (rdap.org) for objects not yet covered. This greatly reduces reliance on the bootstrap server and its rate limits. `.as` now raises `ArgumentError` for invalid AS numbers and `.ip` raises `IPAddr::InvalidAddressError` for invalid IPs (instead of silently querying the bootstrap server). Now requires Ruby >= 3.2. Refresh the bundled files with `rake bootstrap:update`.
- **0.1.5** (2022-12-29) - Add `application/json, */*` fallback Accept types to support rdap.nic.fr which does not like `application/rdap+json` (as of 2022-12-29). I also contacted them to report this issue.
- **0.1.4** (2022-02-01) - Wrap JSON parser errors as RDAP::InvalidReponse and also raise RDAP::EmptyResponse when body is missing
- **0.1.3** (2022-01-10) - Wrap SSL errors as RDAP::SSLError < ServerError < Error
- **0.1.2** (2022-01-07) - Added HTTP headers customization
- **0.1.1** (2021-12-19) - Added TooManyRequests expection in case of 429
- **0.1.0** (2021-12-17) - Initial version

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jarthod/rdap.

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Tests are using the `vcr` gem to record server responses so we don't hit them too quickly/often. This is nice and fast but if the server API even changes we may not notice it. So from time to time it can be intereting to re-record the responses: `rm -R spec/fixtures && rake spec`

The bundled IANA bootstrap files in `data/` should be refreshed before each release with `rake bootstrap:update`, then committed (review the `git diff` to see which TLDs/servers changed).

## Alternatives

If you're looking for a command line tool, you can check the excellent [nicinfo](https://github.com/arineng/nicinfo) (also written in Ruby).
Also if you're just looking for one-off debugging and scripts, you can query a bootstrap endpoint directly using `curl -L`, example:

```
> curl -L https://rdap-bootstrap.arin.net/bootstrap/domain/google.com
{"objectClassName":"domain","handle":"2138514_DOMAIN_COM-VRSN","ldhName":"GOOGLE.COM","links":[{"value":"https:\/\/rdap.verisign.com\/com\/v1\/domain\/GOOGLE.COM","rel":"self","href":"https:\/\/rdap.verisign.com\/com\/v1\/domain\/GOOGLE.COM","type":"application\/rdap+json"},{"value":"https:\/\/rdap.markmonitor.com\/rdap\/domain\/GOOGLE.COM","rel":"related","href":"https:\/\/rdap.markmonitor.com\/rdap\/domain\/GOOGLE.COM","type":"application\/rdap+json"}],"status":["client delete prohibited","client transfer prohibited","client update prohibited","server delete prohibited","server transfer prohibited","server update prohibited"],"entities":[{"objectClassName":"entity","handle":"292","roles":["registrar"],"publicIds":[{"type":"IANA Registrar ID","identifier":"292"}],"vcardArray":["vcard",[["version",{},"text","4.0"],["fn",{},"text","MarkMonitor Inc."]]],"entities":[{"objectClassName":"entity","roles":["abuse"],"vcardArray":["vcard",[["version",{},"text","4.0"],["fn",{},"text",""],["tel",{"type":"voice"},"uri","tel:+1.2083895740"],["email",{},"text","abusecomplaints@markmonitor.com"]]]}]}],"events":[{"eventAction":"registration","eventDate":"1997-09-15T04:00:00Z"},{"eventAction":"expiration","eventDate":"2028-09-14T04:00:00Z"},{"eventAction":"last update of RDAP database","eventDate":"2021-12-17T11:35:32Z"}],"secureDNS":{"delegationSigned":false},"nameservers":[{"objectClassName":"nameserver","ldhName":"NS1.GOOGLE.COM"},{"objectClassName":"nameserver","ldhName":"NS2.GOOGLE.COM"},{"objectClassName":"nameserver","ldhName":"NS3.GOOGLE.COM"},{"objectClassName":"nameserver","ldhName":"NS4.GOOGLE.COM"}],"rdapConformance":["rdap_level_0","icann_rdap_technical_implementation_guide_0","icann_rdap_response_profile_0"],"notices":[{"title":"Terms of Use","description":["Service subject to Terms of Use."],"links":[{"href":"https:\/\/www.verisign.com\/domain-names\/registration-data-access-protocol\/terms-service\/index.xhtml","type":"text\/html"}]},{"title":"Status Codes","description":["For more information on domain status codes, please visit https:\/\/icann.org\/epp"],"links":[{"href":"https:\/\/icann.org\/epp","type":"text\/html"}]},{"title":"RDDS Inaccuracy Complaint Form","description":["URL of the ICANN RDDS Inaccuracy Complaint Form: https:\/\/icann.org\/wicf"],"links":[{"href":"https:\/\/icann.org\/wicf","type":"text\/html"}]}]}
```