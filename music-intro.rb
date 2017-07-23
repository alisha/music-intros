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
  RSpotify.authenticate(S_API_KEY, S_SECRET)

  # artist name
  artistName = params[:artist]
  
  # get name, photo, and genres
  artists = RSpotify::Artist.search(artistName)
  
  if artists.nil? || artists.length == 0
    redirect to ("/error")
  end

  artist = artists.first
  
  @artistName = artist.name
  
  if artist.images.length > 0 && artist.images[0]["url"] != ""
    @photoURL = artist.images[0]["url"]
  end
  
  if artist.genres.length > 0
    @genres = artist.genres.join(", ")
  end
  
  # get related artists
  relatedArtistsList = artist.related_artists

  @relatedArtists = Array.new
  
  if relatedArtistsList.nil? || relatedArtistsList.length > 0
    while @relatedArtists.length < 5 && @relatedArtists.length < relatedArtistsList.length - 1
      @relatedArtists.push(relatedArtistsList[@relatedArtists.length].name)
    end

    @relatedArtists = @relatedArtists.join(", ")
  else
    @relatedArtists = ""
  end

  # get artist's most popular songs
  topTracksList = artist.top_tracks(:US)

  @topTracks = Array.new
  @youTubeURLs = Array.new

  if topTracksList.length > 0

    while @topTracks.length < 5 and @topTracks.length < topTracksList.length - 1
      name = topTracksList[@topTracks.length].name

      # get song title
      @topTracks.push(name)

      # find YouTube video id
      query = "#{name} #{@artistName}".gsub(/[^0-9a-zA-Z ]/i, '').gsub(" ", "+")
      songURLrequest = HTTParty.get("https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=#{query}&type=video&key=#{Y_API_KEY}")

      url = JSON.parse(songURLrequest.body)["items"][0]["id"]["videoId"]

      @youTubeURLs.push(url)

    end
  end

  # make sure @genres is not just a new line or some spaces
  if @genres.nil? || @genres.sub(/[ \t]{2,}\z/, '') == ""
    @genres = ""
  end

  # get artist biography from last.fm
  biographyRequest = HTTParty.get("https://ws.audioscrobbler.com/2.0/?method=artist.getinfo", :query => {
    :api_key => LF_API_KEY,
    :artist => @artistName,
    :format => "json"
  })

  biographyResponse = JSON.parse(biographyRequest.body)

  @biography = biographyResponse["artist"]["bio"]["content"]

  erb :artist

end
