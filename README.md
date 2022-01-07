# RDAP [![Build Status](https://app.travis-ci.com/jarthod/rdap.svg?branch=master)](https://app.travis-ci.com/github/jarthod/rdap)

A minimal Ruby client to query RDAP APIs though a bootstrap server.
No dependencies, no caching or bootstrap file (the query is routed through a bootstrap server first).

[RDAP](https://en.wikipedia.org/wiki/Registration_Data_Access_Protocol) is a new protocol destined to replace WHOIS to query informations about domains, IPs, ASNs, etc.
Not all TLDs support RDAP at the moment, but the deployment is going well: https://deployment.rdap.org

This library is optimal for low volume queries (the [bootstrap server we used here](https://about.rdap.org/) enforces [some throttling](https://about.rdap.org/#rate-limits)).
If you need to perform a lot of queries, you should either:
- avoid bootstrap servers and use a caching client like [nicinfo](https://github.com/arineng/nicinfo)
- or run [your own bootstrap server](https://github.com/arineng/rdap_bootstrap_server).

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

# there is also a lower level method accepting a type (:domain, :ip, :autnum) if needed
RDAP.query("16276", type: :autnum)

# Options
RDAP.domain("google.com", server: "https://rdap-bootstrap.arin.net/bootstrap") # Specify an alternative bootstrap server
RDAP.domain("google.com", server: "https://rdap.verisign.com/com/v1") # Or directly the target RDAP server if you know it
RDAP.domain("google.com", timeout: 20) # Customize open and read timeouts (default = 5 sec each)
RDAP.domain("google.com", headers: {'User-Agent' => 'My application name'}) # Override some HTTP request headers. Default headers are in RDAP::HEADERS

# Error handling
RDAP.domain("test.fr") # TLD not supported yet
# => RDAP::NotFound ([404] domain test.fr not found in IANA boostrap file)
RDAP.domain("jsiqpmcurt.design") # Domain not found
# => RDAP::NotFound ([404] Object not found)
RDAP.domain("jsiqpmcurt.com") # The message is not always exactly the same
# => RDAP::NotFound ([404] Not Found)
RDAP.domain("u$&~(!*@&@^#}") # Invalid URI
# => URI::InvalidURIError (bad URI(is not URI?): "https://rdap.org/domain/u$&~(!*@&@^#}")
RDAP.domain("broken") # Other type of unexpected server response
# => RDAP::ServerError ([500] Internal Server Error)
```

## How does it work

The gem make a query to one of the publicly available RDAP bootstrap server (their responsibility is simply to check the [bootstrap files](https://data.iana.org/rdap/dns.json) and redirect you to the proper RDAP server), then it does the query to the target RDAP server and returns the JSON parsed. The gem currently use this public bootstrap server: https://rdap.org/ but it's possible to change for another one in case of problem or limitation. For example ARIN has it's own bootstrap server too: https://rdap-bootstrap.arin.net/bootstrap. It's also possible to host your own bootstrap server.

## Changelog

- **0.1.2** (2022-01-07) - Added HTTP headers customization
- **0.1.1** (2021-12-19) - Added TooManyRequests expection in case of 429
- **0.1.0** (2021-12-17) - Initial version

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jarthod/rdap.

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Tests are using the `vcr` gem to record server responses so we don't hit them too quickly/often. This is nice and fast but if the server API even changes we may not notice it. So from time to time it can be intereting to re-record the responses: `rm -R spec/fixtures && rake spec`

## Alternatives

If you're looking for a command line tool, you can check the excellent [nicinfo](https://github.com/arineng/nicinfo) (also written in Ruby).
Also if you're just looking for one-off debugging and scripts, you can query a bootstrap endpoint directly using `curl -L`, example:

```
> curl -L https://rdap-bootstrap.arin.net/bootstrap/domain/google.com
{"objectClassName":"domain","handle":"2138514_DOMAIN_COM-VRSN","ldhName":"GOOGLE.COM","links":[{"value":"https:\/\/rdap.verisign.com\/com\/v1\/domain\/GOOGLE.COM","rel":"self","href":"https:\/\/rdap.verisign.com\/com\/v1\/domain\/GOOGLE.COM","type":"application\/rdap+json"},{"value":"https:\/\/rdap.markmonitor.com\/rdap\/domain\/GOOGLE.COM","rel":"related","href":"https:\/\/rdap.markmonitor.com\/rdap\/domain\/GOOGLE.COM","type":"application\/rdap+json"}],"status":["client delete prohibited","client transfer prohibited","client update prohibited","server delete prohibited","server transfer prohibited","server update prohibited"],"entities":[{"objectClassName":"entity","handle":"292","roles":["registrar"],"publicIds":[{"type":"IANA Registrar ID","identifier":"292"}],"vcardArray":["vcard",[["version",{},"text","4.0"],["fn",{},"text","MarkMonitor Inc."]]],"entities":[{"objectClassName":"entity","roles":["abuse"],"vcardArray":["vcard",[["version",{},"text","4.0"],["fn",{},"text",""],["tel",{"type":"voice"},"uri","tel:+1.2083895740"],["email",{},"text","abusecomplaints@markmonitor.com"]]]}]}],"events":[{"eventAction":"registration","eventDate":"1997-09-15T04:00:00Z"},{"eventAction":"expiration","eventDate":"2028-09-14T04:00:00Z"},{"eventAction":"last update of RDAP database","eventDate":"2021-12-17T11:35:32Z"}],"secureDNS":{"delegationSigned":false},"nameservers":[{"objectClassName":"nameserver","ldhName":"NS1.GOOGLE.COM"},{"objectClassName":"nameserver","ldhName":"NS2.GOOGLE.COM"},{"objectClassName":"nameserver","ldhName":"NS3.GOOGLE.COM"},{"objectClassName":"nameserver","ldhName":"NS4.GOOGLE.COM"}],"rdapConformance":["rdap_level_0","icann_rdap_technical_implementation_guide_0","icann_rdap_response_profile_0"],"notices":[{"title":"Terms of Use","description":["Service subject to Terms of Use."],"links":[{"href":"https:\/\/www.verisign.com\/domain-names\/registration-data-access-protocol\/terms-service\/index.xhtml","type":"text\/html"}]},{"title":"Status Codes","description":["For more information on domain status codes, please visit https:\/\/icann.org\/epp"],"links":[{"href":"https:\/\/icann.org\/epp","type":"text\/html"}]},{"title":"RDDS Inaccuracy Complaint Form","description":["URL of the ICANN RDDS Inaccuracy Complaint Form: https:\/\/icann.org\/wicf"],"links":[{"href":"https:\/\/icann.org\/wicf","type":"text\/html"}]}]}
```