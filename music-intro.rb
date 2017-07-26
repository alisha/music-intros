require 'sinatra'
require 'httparty'
require 'json'
require 'rspotify'
# uncomment the line below for running on local machines, where secret.rb contains API keys
# require_relative 'secret'

# get config vars (API keys) from Heroku
Y_API_KEY   = ENV['Y_API_KEY']
S_API_KEY   = ENV['S_API_KEY']
S_SECRET    = ENV['S_SECRET']
LF_API_KEY  = ENV['LF_API_KEY']

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
  artistName = params[:artist]
  
  # get name, photo, and genres
  artistRequest = HTTParty.get("https://ws.audioscrobbler.com/2.0/", :query => {
    :method => "artist.getinfo",
    :artist => artistName,
    :api_key => LF_API_KEY,
    :format => "json"
  })
  
  artistResponse = JSON.parse(artistRequest.body)
  artist = artistResponse["artist"]

  @artistName = artist["name"]

  # get picture, try for largest photo possible
  @photoURL = ""
  photos = artist["image"]
  for photo in photos
    if photo["size"] != ""
      @photoURL = photo["#text"]
    end
  end
  puts @photoURL

  @biography = artist["bio"]["content"]

  # get genres
  genres = []
  for genre in artist["tags"]["tag"]
    genres.push(genre["name"])
  end
  @genres = genres.join(", ")

  # get related artists
  @relatedArtists = []
  for band in artist["similar"]["artist"]
    @relatedArtists.push(band["name"])
  end

  # get top tracks
  topTracksRequest = HTTParty.get("https://ws.audioscrobbler.com/2.0/", :query => {
    :method => "artist.gettoptracks",
    :api_key => LF_API_KEY,
    :artist => @artistName,
    :limit => 5,
    :format => "json"
  })

  topTracksResponse = JSON.parse(topTracksRequest.body)
  
  @topTracks = []
  @youTubeURLs = []

  for i in 0..4 do
    # song titles from last.fm
    title = topTracksResponse["toptracks"]["track"][i]["name"]
    @topTracks.push(title)

    # find song on YouTube
    query = "#{title} #{@artistName}".gsub(/[^0-9a-zA-Z ]/i, '').gsub(" ", "+")
    songURLrequest = HTTParty.get("https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=#{query}&type=video&key=#{Y_API_KEY}")
    url = JSON.parse(songURLrequest.body)["items"][0]["id"]["videoId"]
    @youTubeURLs.push(url)
  end

  erb :artist

end
