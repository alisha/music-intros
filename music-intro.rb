require 'sinatra'
require 'httparty'
require 'json'
require 'rspotify'
# uncomment the line below for running on local machines, where secret.rb contains API keys
require_relative 'secret'

# get config vars (API keys) from Heroku
# Y_API_KEY = ENV['Y_API_KEY']
# S_API_KEY   = ENV['S_API_KEY']
# S_SECRET    = ENV['S_SECRET']
# LF_API_KEY  = ENV['LF_API_KEY']

error 400..510 do
  redirect to('/error')
end


# home
get '/' do
  erb :index
end


# when a user searches for an artist, redirect them to that artist's page
post '/' do
  @artistNameEscaped = params[:artist].gsub(' ', '%20')
  redirect to("/artist/#{@artistNameEscaped}")
end


post '/artist/*' do
  @artistNameEscaped = params[:artist].gsub(' ', '%20')
  redirect to("/artist/#{@artistNameEscaped}")
end


get '/error' do
  erb :error
end


post '/error' do
  @artistNameEscaped = params[:artist].gsub(' ', '%20')
  redirect to("/artist/#{@artistNameEscaped}")
end


get '/artist/:artist' do
  RSpotify.authenticate(S_API_KEY, S_SECRET)

  # artist name
  artistName = params[:artist]
  
  # get name, photo, and genres
  artistRequest = HTTParty.get("https://ws.audioscrobbler.com/2.0/?method=artist.getinfo", :query => {
    :api_key => LF_API_KEY,
    :artist => @artistName,
    :format => "json"
  })

  artistResponse = JSON.parse(artistRequest.body)
  puts artistResponse
  artist = artistResponse["artist"]

  @artistName = artist["name"]

  # get picture, try for largest photo possible
  @photoURL = artist["image size=\"large\""]
  if @photoURL.nil?
    @photoURL = artist["image size=\"medium\""]
  end
  if @photoURL.nil?
    @photoURL = artist["image size=\"small\""]
  end

  @biography = artist["bio"]["content"]

  # get genres
  @genres = []
  for genre in artist.tags
    @genres.push(genre["name"])
  end

  # get related artists
  @relatedArtists = []
  for band in artist.similar
    @relatedArtists.push(band["name"])
  end

  # get top tracks
  topTracksRequest = HTTParty.get("https://ws.audioscrobbler.com/2.0/?method=artist.gettoptracks", :query => {
    :api_key => LF_API_KEY,
    :artist => @artistName,
    :limit => 5,
    :format => "json"
  })

  topTracksResponse = JSON.parse(topTracksRequest.body)
  
  @topTracks = []
  @youTubeURLs = []

  (1..5).each do |i|
    # song titles from last.fm
    title = topTracksResponse["track rank=\"#{i}\""]["name"]
    @topTracks.push(title)

    # find song on YouTube
    query = "#{title} #{@artistName}".gsub(/[^0-9a-zA-Z ]/i, '').gsub(" ", "+")
    songURLrequest = HTTParty.get("https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=#{query}&type=video&key=#{Y_API_KEY}")
    url = JSON.parse(songURLrequest.body)["items"][0]["id"]["videoId"]
    @youTubeURLs.push(url)
  end

  erb :artist

end
