require 'rubygems'
require 'sinatra'
require 'sequel'
require 'nkf'
require 'logger'
require 'sinatra/memcache'
require 'builder'
require 'lib/helpers'
require 'lib/kana'
require 'lib/ad'

get '/:p?' do |p|
  p = (p || 1).to_i
  p = 1 if p < 1
  k = params[:k]
  cache "mindex:#{p}:#{k}" do
    @p = p
    ds = DB[:boards].filter(:active => true).order(:updated_at.desc)

    unless k.nil? || k.empty?
      k = NKF.nkf('-S -w', k)
      ds = ds.filter(:title.like("%#{k}%"))
      @k = NKF.nkf('-s', k)
      @ku = k
    end

    limit = 30
    @paginate, @boards = paginate(p, ds, limit)
    erb :index
  end
end

get '/t/:id/:p' do |id, p|
  p = (p || 1).to_i
  p = 1 if p < 1
  cache "mthread:#{id}:#{p}" do
    @p = p
    @board = DB[:boards][:id => id]
    halt erb(:bad) unless @board

    ds = DB[:pictures].filter(:active => true).filter(:board_id => id).order(:created_at.desc)
    limit = 5
    @paginate, @pictures = paginate(p, ds, limit)
    halt erb(:nopic) if @pictures.empty?
    erb :thread
  end
end

get '/i/:pid' do |pid|
  cache "mimage:#{pid}" do
    @picture = DB[:pictures].filter(:active => true)[:id => pid]
    halt erb(:bad) unless @picture

    @board = DB[:boards][:id => @picture[:board_id]]
    halt erb(:bad) unless @board

    @tid = @board[:thread_id]
    @path = @picture[:url]
    erb :image
  end
end

get '/l/:pid' do |pid|
  cache "mimage:#{pid}" do
    @picture = DB[:pictures].filter(:active => true)[:id => pid]
    halt erb(:bad) unless @picture

    @board = DB[:boards][:id => @picture[:board_id]]
    halt erb(:bad) unless @board

    @tid = @board[:thread_id]
    @path = @picture[:url]
    erb :large
  end
end

get '/notice/confirm/:pid' do |pid|
  @p = DB[:pictures].filter(:id => pid).first
  redirect '/' unless @p

  erb :notice_confirm
end

post '/notice/send' do
  pid = params[:pid]
  p = DB[:pictures].filter(:id => pid)
  redirect '/' unless p.first

  p.update(:active => false)
  erb :notice
end

get '/sitemap/google.xml' do
  content_type 'application/xml'
  cache 'msitemap', :expiry => 36000, :compress => true do
    @boards = DB[:boards].all
    builder :sitemap
  end
end

# ---

before do
  content_type 'application/xhtml+xml'
end

helpers do
  alias_method :_erb, :erb

  def erb(key, option = {})
    NKF.nkf('-s -x', _erb(key, option).to_hankaku)
  end

  def static(path = nil)
    options.static_url + path.to_s
  end

  def paginate(page, ds, limit = 10)
    offset = (page - 1) * limit
    count = ds.count
    p_max = (count.to_f / limit).ceil
    data = ds.limit(limit, offset).all
    paginate = {
      :count => count,
      :current_page => page,
      :next_page => page < p_max ? page + 1 : nil,
      :prev_page => page > 1 ? page - 1 : nil,
      :max_page => p_max,
      :from => page * limit - limit + 1,
      :to => page * limit > count ? count : page * limit
    }
    [paginate, data]
  end

  def mobile_page_link(p, url, params = '')
    html = []
    if p[:prev_page]
      html << %{<a href="#{url}/#{p[:prev_page]}#{params}" accesskey="1">[1]前</a>}
    end
    if p[:next_page]
      html << %{<a href="#{url}/#{p[:next_page]}#{params}" accesskey="3">[3]次</a>}
    end
    html = %{#{p[:from]}-#{p[:to]}/#{p[:count]}<br />} << html.join('|')
    %{<div style="text-align:right;">#{html}</div>}
  end

  def hr
    %{<hr style="height:1px;border:solid 1px #eee" />}
  end

  def s(color ='f86')
    %{<span style="color:##{color}">◆</span>}
  end

  def last_updated
    DB[:histories].reverse_order(:id).first[:value].gsub('.', '/')
  end
end

configure do
  set :cache_namespace, "pic2ch"
end

configure :development do
  DB = Sequel.connect('sqlite:///Users/kazuki/Documents/p2m/dev.db')
  DB.logger = Logger.new(STDOUT)
  set :static_url, ""
  set :cache_enable, false
end

configure :production do
  DB = Sequel.connect('sqlite:///home/gioext/pic2ch/db/production.sqlite3')
  set :static_url, "http://strage.giox.info"
  set :cache_logging, false

  not_found do
    content_type 'application/xhtml+xml'
    erb '<div><a href="/">TOP</a></div>'
  end

  error do
    content_type 'application/xhtml+xml'
    erb '<div><a href="/">TOP</a></div>'
  end
end
