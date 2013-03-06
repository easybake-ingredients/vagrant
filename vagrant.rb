require 'json'
require 'open-uri'
require 'chef/version_constraint'
require 'chef/mixin/checksum'
require 'chef/exceptions'
require 'net/https'
require 'uri'
require 'nokogiri'

class TheFile
  include Chef::Mixin::Checksum
end

# This generates data bags to be used by an artifact repository
# of some type powered by chef

d=Nokogiri::HTML(open('http://downloads.vagrantup.com/'))
base_url='https://opscode-omnitruck-release.s3.amazonaws.com'
download_page=Nokogiri::HTML(open('http://downloads.vagrantup.com/'))

def download_file(source,destination)
  url = URI.parse source
  http = Net::HTTP.new(url.host, url.port)
  if not File.exists? destination
    puts "Downloading #{source} to #{destination}"
    open(destination,'wb') do |f|
      req = http.request_get(source)
      if req.code != '200'
        puts "Error downloading file: #{req.code} #{req.body}"
        exit 1
      end
      f.write(req.body)
            f.close
    end
  end
end

artifacts = Hash.new
download_page.search('//a[@class="tag"]').map{|n| n.attributes['href'].value}.each do |ver_url|
  vagrant_ver = ::File.basename(ver_url)
  semantic_ver = vagrant_ver[1..-1]
  # I only want 1.0.6 or higher
  next if not Chef::VersionConstraint.new(">= 1.0.6").include? semantic_ver
  d=Nokogiri::HTML(open(ver_url))

  package_urls = d.search('//a[@class]').select{|a| a['class'] =~ /^file/}.map{|a| a['href']}
  package_urls.each do |package_url|
    package_filename = ::File.basename(package_url)
    cached_packagefile = package_filename
    dbi_safe_ver = vagrant_ver.gsub('.','_')
    arch = case package_filename
           when /x86_64/
             'x86_64'
           when /i686/
             'i686'
           when /./
             ['i686','x86_64']
           end
    case package_filename.split('.').last
    when 'dmg'
      dbi_name = "osx_#{dbi_safe_ver}"
      os = {
        'mac_os_x' => [
          '10.7',
          '10.8'
        ]
      }
    when 'msi'
      dbi_name = "windows_#{dbi_safe_ver}"
      os = {
        'windows' => [
          '2008r2',
          '2012',
          '7',
          '8'
          ]
      }
    when 'deb'
      dbi_name = "debian+ubuntu_#{arch}_#{dbi_safe_ver}"
      os = {
        'ubuntu' => [
          '10.04',
          '10.10',
          "11.04",
          "11.10",
          "12.04",
          "12.10"
        ],
        "debian" => [
          "6"
        ]
      }
    when 'rpm'
      dbi_name = "el_#{arch}_#{dbi_safe_ver}"
      os = {
        'el' => [
          '5',
          '6'
        ],
        "sles" => [
          "11.2",
          "12.2"
        ]
      }
    when 'xz'
      next # skipping for now
    end
    download_file(package_url,cached_packagefile)
    artifacts[dbi_name] ||= Hash.new
    artifacts[dbi_name][:source] ||= package_url
    artifacts[dbi_name][:filename] ||= package_filename
    artifacts[dbi_name][:arch] ||= arch
    artifacts[dbi_name][:checksum] ||= TheFile.new.checksum(cached_packagefile)
    artifacts[dbi_name][:version] ||= vagrant_ver
    artifacts[dbi_name][:semantic_version] ||= semantic_ver
    artifacts[dbi_name][:os] ||= os
  end
end


#puts JSON.pretty_generate(artifacts)
# Write out all data bag json
artifacts.each do |dbi,data|
  open(dbi+'.json','w') do |f|
    f.write JSON.pretty_generate({id: dbi}.merge(data))
    f.close
  end
end
