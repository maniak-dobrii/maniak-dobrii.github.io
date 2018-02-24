---
layout: post
title: Extracting stuff from provisioning profiles
---

Say, you're in a [Ruby](https://www.ruby-lang.org) script, for example, [fastlane](https://github.com/fastlane/fastlane) `Fastfile` and you need to extract information from `.mobileprovision` file, like `UUID`, `Team Identifier`, `Code Signing Identity` or whatever. Here's how.

This all is targeted for iOS development on a mac, but (I think) it might be found usefull in unpredicted ways.

## CMS encoded provisioning profile files
If you try to view some `provisioning_profile.mobileprovision` file contents:

```shell
cat provisioning_profile.mobileprovision
```

you'll end up with garbage, because provisioning profiles are in [Cryptographic&nbsp;Message&nbsp;Syntax&nbsp;(CMS)](https://tools.ietf.org/html/rfc3852) format.
You need to decode it:

```shell
# cms - Encode or decode CMS encrypted message
# -D - decode a CMS message
# -i - use infile as source of data (default: stdin)
security cms -D -i provisioning_profile.mobileprovision
```

That gives you plist xml that you can inspect:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AppIDName</key>
	<string>App ID Name</string>
	<key>ApplicationIdentifierPrefix</key>
	<array>
		<string>ABC123DEF4</string>
	</array>
	<key>CreationDate</key>
	<date>2042-10-15T15:20:42Z</date>
	<key>Platform</key>
	<array>
		<string>iOS</string>
	</array>
	<key>DeveloperCertificates</key>
		<array>
		<data>%Long human-unreadable Base64 encoded certificate%</data>
		</array>
	<key>Entitlements</key>
	<dict>
		<key>keychain-access-groups</key>
		<array>
			<string>ABC123DEF4.*</string>		
		</array>
		<key>get-task-allow</key>
		<false/>
		<key>application-identifier</key>
		<string>ABC123DEF4.com.your.bundle.id</string>
		<key>com.apple.developer.team-identifier</key>
		<string>U1R23TEAMID</string>
		<key>aps-environment</key>
		<string>production</string>
		<key>beta-reports-active</key>
		<true/>
	</dict>
	<key>ExpirationDate</key>
	<date>2044-10-15T15:20:42Z</date>
	<key>Name</key>
	<string>Profile Name</string>
	<key>TeamIdentifier</key>
	<array>
		<string>U1R23TEAMID</string>
	</array>
	<key>TeamName</key>
	<string>Your team name</string>
	<key>TimeToLive</key>
	<integer>364</integer>
	<key>UUID</key>
	<string>thats-your-profile-uuid-string</string>
	<key>Version</key>
	<integer>1</integer>
</dict>
</plist>
```

While in Ruby there are [number of ways](http://stackoverflow.com/questions/2232/calling-shell-commands-from-ruby) to perform shell commands, fastlane has [sh action](https://github.com/fastlane/fastlane/blob/master/fastlane/lib/fastlane/helper/sh_helper.rb) for shelling out. You can execute shell commands using `sh("command")` like this:

```ruby
provision_profile_file_path = "provisioning_profile.mobileprovision"
output_plist_file = "profile.plist"

# Shell out
# This will decode provisioning profile into plist xml
# and save result into the file
sh("security cms -D -i #{provision_profile_path} > #{output_plist_file}")
```

## Extracting plist values in Ruby
Now, when you have the plist file, you can read it and extract values. Since it is just xml, you can use any method you prefer, but I suggest using [plist](http://plist.rubyforge.org/) library, you use it like this:

```ruby
require 'plist'

profile_plist = Plist.parse_xml("profile.plist")
profile_plist['key'] # this returns value for a key
```

Here are some examples used against plist given above:

```ruby
require 'plist'

profile_plist = Plist.parse_xml("profile.plist")

profile_plist['UUID']
# => "thats-your-profile-uuid-string"

# `TeamIdentifier` is an array of strings, get the first item
profile_plist['TeamIdentifier'].first
# => "U1R23TEAMID"
```

Some data is incapsulated, for example, if you need `Code Sign Identity` or other certificate details, it won't be surprising that you need to inspect certificates compatible with this provisioning profile.

## Extracting code sign identity
List of compatible certificates is stored behind `DeveloperCertificates` key.  It's an array of [Base64](http://tools.ietf.org/html/rfc4648) encoded data chunks. You'll need to Base64 decode them prior to use.

```xml
...
<key>DeveloperCertificates</key>
<array>
<data>UkdWamIyUmxJR2R2Yllpd2dibUZoYUMsIG5hYWgsIGp1c3Qgam9raW5nPSk=</data>
</array>
...
```

If you have Base64 encoded file, you can use this shell command to decode it:

```shell
# -D - decode
cat base64_encoded_file | base64 -D
```
or, without a file:

```shell
echo "base64_encoded_string" | base64 -D
```

But, luckily, if you use the plist library from above, you don't even need to shell out:

```ruby
# decode first certificate into string
certificate = profile['DeveloperCertificates'].first.string
```

If you try to use that string, you'll notice that it is not much human-readable, also it is not xml.  It's a [X.509 DER](https://en.wikipedia.org/wiki/X.509) certificate, you need to decode it, for example via `openssl`:

```shell
# assume your X.509 DER certificate is in `x509_der_cert_file`
# x509 - specifies X.509 standard
# -inform DER - specifies X.509 DER format
# -noout - by default it outputs certificate, this disables it
# -subject - print subject distinguished name
cat x509_der_cert_file | openssl x509 -noout -inform DER -subject
```

This gives something we could work with:

```
subject= /UID=U1R23TEAMID/CN=iPhone Distribution: Company Blah/OU=U1R23TEAMID/O=Company LLC/C=RU
```

`CN` is code sign identity. I couldn't resist to [introduce more problems](https://blog.codinghorror.com/regular-expressions-now-you-have-two-problems/), that's why I extracted `CN` value via regular expression and `sed`, here's what I've come up with:

```
# Groove capture group in the middle, everything between "CN=" and "/"
^.*CN=(.*?)\/.*$
```

but it does not work with `sed` (even with `-E`), so I've updated it to:

```
# Everything between "CN=" and "/" that does not contain "/"
^.*CN=([^\/]*)\/.*$
```

with sed, if you use "basic regular expressions" you have to escape brackets:

```shell
# s for regular expression substitute
# s/regular expression/replacement/flags
# \1 - return capture group 1
sed 's/^.*CN=\([^\/]*\)\/.*$/\1/'

# If you use extended regular expressions you don't need to escape brackets
# -E - interpret regular expression as extended (modern)
sed -E 's/^.*CN=([^\/]*)\/.*$/\1/'
```

When you shell out from Ruby you'll need to escape those backslashes again. Here's a recap:

1. take (base64 decoded) certificate file, 
2. decode it again assuming it is `X.509 DER` certificate 
3. extract `CN` value:

```ruby
sh("cat #{decoded_cert_file_name} | openssl x509 -noout -inform DER -subject | sed 's/^.*CN=\\([^\\/]*\\)\\/.*$/\\1/'")
# => iPhone Distribution: Company Blah
```

Here's also shell version of the complete `Code Sign Identity` extraction from the base64 encoded certificate file:

```shell
cat test_cert.base64 | base64 -D | openssl x509 -noout -inform DER -subject | sed 's/^.*CN=\([^\/]*\)\/.*$/\1/'
```


------

I gave you *how*, but I won't give you *why*. Probably, if you need this, you rather doing something really specific or missing the correct and easy way. Make sure it is not the latter.


### Bonus
Want Finder preview (select a file and hit `Space`) be more informative for provision profiles? Like this:
![ProvisionQL teaser]({{ site.baseurl }}/images/posts/extracting-stuff-from-provisioning-profile/provisionQLTeaser.png)

Than here's [ProvisionQL](https://github.com/ealeksandrov/ProvisionQL), it is very useful, and also works for `.ipa` files. See [what it can do](https://github.com/ealeksandrov/ProvisionQL/blob/master/Screenshots/README.md).
