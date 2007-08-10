# This is a lightweight read-only wrapper for the
# SmugMug API.  Currently uses the REST endpoint and 
# the beta 1.2.0 API
#
# As this wrapper is, as of now, read only, all requests are
# GET requests.
#
# Note- the documentation provided is meant to act as a quick reminder, 
# it is not meant to replace the wiki. http://smugmug.jot.com/WikiHome/1.2.0


# Author:: David Leatherman
# Copyright:: Copyright (c) 2007 David Leatherman
# License:: 
# Date:: May 19, 2007

require 'rubygems'
require 'xmlsimple'
require 'net/https'

module SmugMug
  class Base
    attr_accessor :api_key, :session_id, :xml_options

    # api_key:: The only required parameter is your api_key.  If you don't have an api key yet
    #           go to http://www.smugmug.com/hack/apikeys to get one.
    # use_ssl:: Connect via ssl.  Recommended if you are using login_with_password and login_with_hash
    # xml_options:: These options are passed directly to XmlSimple.  The default output from XmlSimple is
    #               very array heavy so when you don't need to convert the parsed object back to XML, a
    #               useful value for this is:  { 'GroupTags' => { 'Albums' => 'Album', 'Images' => 'Image'}, 'forceArray' => false}
    def initialize(api_key, use_ssl = false, xml_options = {})
      @xml_options = xml_options
      @api_key = api_key
      connect(use_ssl)
    end

    # Create the connection with or without using SSL
    def connect(use_ssl = false)
      @connection = Net::HTTP.new("api.smugmug.com", use_ssl ? 443 : 80)
      @connection.use_ssl = use_ssl
      @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE if use_ssl
    end

    # Sends a request to SmugMug and parses the result with XmlSimple
    # method:: The SmugMug method name to call
    # parameters:: URL params for the request
    # requires_login:: Does this method require a valid login session. False only for the login methods. 
    def request(method, parameters = {}, requires_login = true)
      raise "Not logged in (no session id)." if @session_id == nil && requires_login

      parameters['APIKey']=@api_key
      parameters['SessionID']=@session_id if @session_id != nil
      params = parameters.to_a.map {|a| a.join('=')}.join('&')
      response = @connection.request_get("/hack/rest/1.2.0/?method=#{method}&#{params}", 'User-Agent' => 'smugmug.rb/0.1 (SmugMug Ruby API)')

      if response.code == "200"
        result = XmlSimple.xml_in(response.body, @xml_options)
        if result['stat'] != 'ok'
          raise "Error occurred (stat: #{result['stat']} message: #{result['message']} code: #{result['code']}"
        end
        result
      else
        raise "Error occured (#{response.code}): #{response.body}"
      end
    end

    # Login methods

    # Base login method.  Responsible for saving the session_id
    def login(method, parameters = {})
      resp = request method, parameters, false
      @session_id = resp['Login'][0]!=nil ? resp['Login'][0]['Session'][0]['id'] : resp['Login']['Session']['id']
      resp
    end

    # Logging in this way will grant access to any publicly available album or image
    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.login.anonymously
    #
    def login_anonymously
      login 'smugmug.login.anonymously'
    end

    # Logging in with your SmugMug account email address and password will give you
    # access to all of your albums (as well as any other public album).  NOTE: Your
    # password will be sent in the clear.  Use SSL when logging in this way or use login_with_hash
    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.login.withPassword
    #
    def login_with_password(email, password)
      login 'smugmug.login.withPassword', {'EmailAddress' => email, 'Password' => password}
    end

    # This is the same as login_with_password except you will login with a numeric userId
    # and an encrypted password.  Both of these are available in the response from 
    # login_with_password.  It is recommended to login once with login_with_password
    # to get your id and hash and to use it from then on.  SSL is still recommended when using login_with_hash.
    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.login.withHash
    #
    def login_with_hash(userid, pass_hash)
      login 'smugmug.login.withHash', {'UserID' => userid, 'PasswordHash' => pass_hash }
    end


    # Logout

    # Terminates your SmugMug sessionId
    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.logout
    #
    def logout
      request 'smugmug.logout'
      @session_id = nil
    end


    # Users

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.users.getTree
    def user_tree(heavy=false, nickname='', site_password='')
      #smugmug.users.getTree
      hv = heavy ? '1' : '0'
      request 'smugmug.users.getTree', {'Heavy'=> hv, 'NickName'=>nickname, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.users.getTransferStats
    #
    # month:: integer
    # year:: integer
    def user_transfer_stats(month, year)
      #smugmug.users.getTransferStats
      request 'smugmug.users.getTransferStats', {'Month'=> month, 'Year'=>year}
    end


    # Albums ----

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.get
    #
    def albums(heavy=false, nickname='', site_password='')
      #smugmug.albums.get
      hv = heavy ? '1' : '0'
      request 'smugmug.albums.get', {'Heavy'=> hv, 'NickName'=>nickname, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.getInfo
    #
    def album_info(album_id, password = '', site_password = '')
      #smugmug.albums.getInfo
      request 'smugmug.albums.getInfo', {'AlbumID'=> album_id, 'Password'=>password, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albums.getStats
    #
    def album_stats(album_id, month, year, heavy=false)
      #smugmug.albums.getStats
      hv = heavy ? '1' : '0'
      request 'smugmug.albums.getStats', {'Heavy'=> hv, 'Month'=>month, 'Year'=>year}
    end


    # Album Templates ----

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.albumtemplates.get
    #
    def album_templates
      #smugmug.albumtemplates.get
      request 'smugmug.albumtemplates.get'
    end


    # Images ----

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.get
    #
    def images(album_id, heavy=false, password='', site_password='' )
      #smugmug.images.get
      hv = heavy ? '1' : '0'
      request 'smugmug.images.get', {'AlbumID'=> album_id, 'Heavy'=>hv, 'Password'=>password, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getURLs
    #
    def image_urls(image_id, template_id=3, password='', site_password='' )
      #smugmug.images.getURLs
      request 'smugmug.images.getURLs', {'ImageID'=> image_id, 'TemplateID'=>template_id, 'Password'=>password, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getInfo
    #
    def image_info(image_id, password='', site_password='' )
      #smugmug.images.getInfo
      request 'smugmug.images.getInfo', {'ImageID'=> image_id, 'Password'=>password, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getEXIF
    #
    def image_exif(image_id, password='', site_password='' )
      #smugmug.images.getEXIF
      request 'smugmug.images.getEXIF', {'ImageID'=> image_id, 'Password'=>password, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.images.getStats
    #
    def image_stats(image_id, month)
      #smugmug.images.getStats
      request 'smugmug.images.getStats', {'ImageID'=> image_id, 'Month'=>month}
    end


    # Categories ----

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.categories.get
    #
    def categories(nickname='', site_password='')
      #smugmug.categories.get
      request 'smugmug.categories.get', {'NickName'=>nickname, 'SitePassword'=>site_password}
    end

    # Wiki URL: http://smugmug.jot.com/WikiHome/1.2.0/smugmug.subcategories.get
    #           http://smugmug.jot.com/WikiHome/1.2.0/smugmug.subcategories.getAll
    #
    def subcategories(category_id=nil, nickname='', site_password='')
      #smugmug.subcategories.get
      #smugmug.subcategories.getAll if no category id
      if category_id == nil
        request 'smugmug.subcategories.getAll', {'NickName'=>nickname, 'SitePassword'=>site_password}
      else
        request 'smugmug.subcategories.get', {'CategoryID'=>category_id, 'NickName'=>nickname, 'SitePassword'=>site_password}
      end
    end
  end
end