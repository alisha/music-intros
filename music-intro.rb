require 'sinatra'
require 'shotgun'
require 'httparty'
require 'json'
require 'rspotify'
require_relative 'secret'

# home
get '/' do
  # get popular artists
  artistsRequest = HTTParty.get("http://developer.echonest.com/api/v4/artist/top_hottt", :query => {
    :api_key => EN_API_KEY,
    :format => "json",
    :results => 5
  })

  @topArtists = Array.new

  artistsResponse = JSON.parse(artistsRequest.body)["response"]

  if artistsResponse["status"]["code"] == 0 && artistsResponse["artists"].length > 0

    artistsResponse["artists"].each do |artist|
      @topArtists.push(artist["name"])
      puts artist
    end

  end

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


get '/artist/:artist' do

  # artist name
  artistName = params[:artist]

  # get name, photo, and genres
  artist = RSpotify::Artist.search(artistName).first

  @artistName = artist.name
  @photoURL = artist.images[0]["url"]
  @genres = artist.genres.join(", ")

  # get related artists
  relatedArtistsList = artist.related_artists

  @relatedArtists = Array.new

  if relatedArtistsList.length > 0
    while @relatedArtists.length < 5 && @relatedArtists.length < relatedArtistsList.length
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

    while @topTracks.length < 5
      name = topTracksList[@topTracks.length].name

      # get song title
      @topTracks.push(name)

      # find YouTube video id
      query = "#{name} #{@artistName}".gsub(/[^0-9a-zA-Z ]/i, '').gsub(" ", "+")
      songURLrequest = HTTParty.get("https://www.googleapis.com/youtube/v3/search?part=snippet&q=#{query}&type=video&maxResults=1&key=#{Y_API_KEY}")

      url = JSON.parse(songURLrequest.body)["items"][0]["id"]["videoId"]

      @youTubeURLs.push(url)

    end
  end

  # get genres from EchoNest if they're not on Spotify
  if @genres == ""
    genreList = Array.new

    genreRequest = HTTParty.get("http://developer.echonest.com/api/v4/artist/search", :query => {
      :api_key => EN_API_KEY,
      :name => @artistName,
      :bucket => "genre",
      :format => "json",
      :results => 1
    })

    genreResponse = JSON.parse(genreRequest.body)["response"]

    if genreResponse["status"]["code"] == 0 && genreResponse["artists"][0]["genres"].length > 0

      genreResponse["artists"][0]["genres"].each do |genre|
        genreList.push(genre["name"])
      end

      @genres = genreList.join(', ')
    end

  end

  # get artist biography
  biographyRequest = HTTParty.get("http://developer.echonest.com/api/v4/artist/biographies", :query => {
    :api_key => EN_API_KEY,
    :name => @artistName,
    :format => "json",
    :results => 15
  })

  biographyResponse = JSON.parse(biographyRequest.body)

  if biographyResponse["response"]["status"]["code"] == 0 && biographyResponse["response"]["biographies"].length > 0
    
    # biographies must be at least 15 words
    biographyResponse = biographyResponse["response"]["biographies"].sort_by {|x| x["text"].length}

    biographyResponse.each do |bio|
      if bio["text"].split(' ').length > 15
        @biography = bio["text"]
        break
      end
    end
  else
    @biography = ""
  end

  erb :artist

end
