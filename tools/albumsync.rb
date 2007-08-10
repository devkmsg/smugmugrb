#!/usr/local/bin/ruby
# == Usage 
# 
# ruby rslide.rb PATH
#   -h, -?, --help  -  This message
#   --apikey=KEY -  Your SmugMug API Key - 
#                   If you don't have an api key yet go to 
#                    http://www.smugmug.com/hack/apikeys to get one.
#   --nickname=NAME -  The name of the use 
#                      I.e., the first part of the users url.
#                        "bob" in this example bob.smugmug.com
#   --album=ALBUM   -  The name of the album

# Author:: David Leatherman
# Copyright:: Copyright (c) 2007 David Leatherman
# License:: Ruby License, http://www.ruby-lang.org/en/LICENSE.txt.
# Date:: June 10, 2007

require 'optparse' 
require 'rdoc/ri/ri_paths' #Needed for rdoc/usage
require 'rdoc/usage'
require '../smugmug'
require 'pp'

class AlbumSync
  attr_accessor :api_key, :nickname, :album, :quiet
  
  def initialize(api_key, nickname, album, quiet)
    @smugmug = SmugMug::Base.new(api_key, true, { 'GroupTags' => { 'Albums' => 'Album', 'Images' => 'Image'}, 'forceArray' => false})
    @smugmug.login_anonymously
    
    @quiet = quiet
    @api_key = api_key
    @nickname = nickname
    @album = album
  end
  
  def sync
    id = find_album_id
    raise "Album, #{@album}, not found." if id.nil?

    remote_imgs = remote_images(id)
    remote_imgs_map = {}
    remote_imgs.each do |img|
      remote_imgs_map[img.split('/').last] = img
    end
    raise "There are no images in album, #{@album}." if remote_imgs.empty?
    
    Dir.mkdir(@album) unless File.exists?(@album)
    Dir.chdir(@album)
    imgs = local_images

    imgs_to_add = remote_imgs_map.keys - imgs
    imgs_to_del = imgs - remote_imgs_map.keys

    log "No new images to download." if imgs_to_add.empty?
    imgs_to_add.each do |img|
      fetch_image(img, remote_imgs_map[img])
    end
    
    log "No old images to delete" if imgs_to_del.empty?
    imgs_to_del.each do |img|
      delete_image(img)
    end
    Dir.chdir("..")
  end
  
  def find_album_id
    log "Fetching album information"
    id = nil
    albums = @smugmug.albums(false, @nickname)
    albums['Albums'].each do |album|
      id = album['id'] if( album['Title'].downcase == @album )
    end
    id
  end
  
  def remote_images(id)
    log "Fetching remote image list"
    imgs = []
    images = @smugmug.images(id, true)
    images['Images'].each do |image|
      imgs << image['LargeURL']
    end
    imgs
  end
  
  def local_images
    log "Fetching local image list"
    Dir.glob("*.jpg")
  end
  
  
  
  def fetch_image(local, remote)
    log("Fetching #{remote}")
    uri = URI.parse(remote)
    resp = Net::HTTP.get_response(uri.host, uri.path)
    open(local, "wb") { |file|
      file.write(resp.body)
    }  
  end
  
  def delete_image(img)
    log "Removing #{img}."
    File.delete(img)
  end
  
  def log(msg)
    puts msg unless @quiet
  end
end


album = nil
nickname = nil
api_key = nil
quiet = false

opts = OptionParser.new
opts.on("-h", "-?", "--help") { RDoc::usage }
opts.on("--album=ALBUM") {|val| album = val }
opts.on("--apikey=KEY") {|val| api_key = val }
opts.on("--nickname=NAME") {|val| nickname = val }
opts.on("-q", "--quiet") {|val| quiet = true }
path = opts.parse(ARGV) rescue RDoc::usage('usage')

if album.nil? || nickname.nil? || api_key.nil? then
  RDoc::usage('usage')
else
  album_sync = AlbumSync.new(api_key, nickname, album, quiet)
  album_sync.sync
end




