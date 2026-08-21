package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// canonicalQueryNames contains Jellyfin's public query parameter spelling.
// The lookup is case-insensitive, which covers clients such as Jellyfin Roku
// that send fully lowercase names. Unknown parameters pass through unchanged.
var canonicalQueryNames = newCanonicalQueryNames([]string{
	"AdjacentTo",
	"AlbumArtistIds",
	"AlbumIds",
	"Albums",
	"ArtistIds",
	"Artists",
	"AudioCodec",
	"AudioStreamIndex",
	"AutoOpenLiveStream",
	"CollapseBoxSetItems",
	"ContributingArtistIds",
	"DeviceId",
	"DeviceProfileId",
	"DirectPlayAudioChannels",
	"EnableAutoCast",
	"EnableDirectPlay",
	"EnableDirectStream",
	"EnableImageTypes",
	"EnableImages",
	"EnableMediaSourceDisplay",
	"EnableRewatching",
	"EnableResumable",
	"EnableTotalRecordCount",
	"EnableTranscoding",
	"EnableUserData",
	"ExcludeArtistIds",
	"ExcludeItemIds",
	"ExcludeItemTypes",
	"Fields",
	"Filters",
	"GenreIds",
	"Genres",
	"GroupItems",
	"HasImdbId",
	"HasOverview",
	"HasParentalRating",
	"HasSpecialFeature",
	"HasSubtitles",
	"HasThemeSong",
	"HasThemeVideo",
	"HasTmdbId",
	"HasTrailer",
	"HasTvdbId",
	"Ids",
	"ImageTypeLimit",
	"ImageTypes",
	"IncludeItemTypes",
	"IncludeMedia",
	"IncludePeople",
	"IncludeStudios",
	"IndexNumber",
	"Is3D",
	"Is4K",
	"IsFavorite",
	"IsFolder",
	"IsHD",
	"IsKids",
	"IsLocked",
	"IsMissing",
	"IsMovie",
	"IsNews",
	"IsPlaceHolder",
	"IsPlayed",
	"IsSeries",
	"IsSports",
	"IsUnaired",
	"Limit",
	"LiveStreamId",
	"LocationTypes",
	"MaxHeight",
	"MaxOfficialRating",
	"MaxPremiereDate",
	"MaxStreamingBitrate",
	"MaxWidth",
	"MediaSourceId",
	"MediaTypes",
	"MinCommunityRating",
	"MinCriticRating",
	"MinDateLastSaved",
	"MinDateLastSavedForUser",
	"MinHeight",
	"MinOfficialRating",
	"MinPremiereDate",
	"MinWidth",
	"NameLessThan",
	"NameStartsWith",
	"NameStartsWithOrGreater",
	"NextUpDateCutoff",
	"OfficialRatings",
	"ParentId",
	"ParentIndexNumber",
	"Person",
	"PersonIds",
	"PersonTypes",
	"PlaySessionId",
	"Profile",
	"Quality",
	"Recursive",
	"SearchTerm",
	"SeasonId",
	"SeriesId",
	"SeriesStatus",
	"SortBy",
	"SortOrder",
	"StartIndex",
	"StartTimeTicks",
	"Static",
	"StudioIds",
	"Studios",
	"SubtitleStreamIndex",
	"Tag",
	"Tags",
	"TranscodingMaxAudioChannels",
	"UserId",
	"VideoCodec",
	"VideoType",
	"VideoTypes",
	"Width",
	"Years",
})

func newCanonicalQueryNames(names []string) map[string]string {
	result := make(map[string]string, len(names))
	for _, name := range names {
		result[strings.ToLower(name)] = name
	}
	return result
}

func normalizeQuery(values url.Values) url.Values {
	result := make(url.Values, len(values))

	// Preserve correctly-cased values first. If a malformed request supplies
	// both variants, the canonical spelling deliberately takes precedence.
	for name, value := range values {
		canonical, known := canonicalQueryNames[strings.ToLower(name)]
		if !known || name == canonical {
			result[name] = append([]string(nil), value...)
		}
	}
	for name, value := range values {
		canonical, known := canonicalQueryNames[strings.ToLower(name)]
		if !known || name == canonical {
			continue
		}
		if _, exists := result[canonical]; !exists {
			result[canonical] = append([]string(nil), value...)
		}
	}

	return result
}

func normalizePath(path string) string {
	if strings.EqualFold(path, "/items/") {
		return strings.TrimSuffix(path, "/")
	}
	return path
}

func isItemDetailPath(path string) bool {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	return len(parts) == 2 && strings.EqualFold(parts[0], "items") && parts[1] != ""
}

func patchItemDetailResponse(response *http.Response) error {
	if response.Request.Method != http.MethodGet ||
		response.StatusCode != http.StatusOK ||
		!isItemDetailPath(response.Request.URL.Path) ||
		!strings.HasPrefix(strings.ToLower(response.Header.Get("Content-Type")), "application/json") ||
		response.Header.Get("Content-Encoding") != "" {
		return nil
	}

	body, err := io.ReadAll(response.Body)
	if err != nil {
		return err
	}
	_ = response.Body.Close()
	response.Body = io.NopCloser(strings.NewReader(string(body)))

	var item map[string]json.RawMessage
	if err := json.Unmarshal(body, &item); err != nil {
		return nil
	}
	for name := range item {
		if strings.EqualFold(name, "MediaStreams") {
			return nil
		}
	}

	var mediaSources json.RawMessage
	for name, value := range item {
		if strings.EqualFold(name, "MediaSources") {
			mediaSources = value
			break
		}
	}
	if len(mediaSources) == 0 {
		return nil
	}

	var sources []map[string]json.RawMessage
	if err := json.Unmarshal(mediaSources, &sources); err != nil || len(sources) == 0 {
		return nil
	}
	mediaStreams := json.RawMessage("[]")
	for name, value := range sources[0] {
		if strings.EqualFold(name, "MediaStreams") && len(value) != 0 && string(value) != "null" {
			mediaStreams = value
			break
		}
	}
	item["MediaStreams"] = mediaStreams

	patchedBody, err := json.Marshal(item)
	if err != nil {
		return err
	}
	response.Body = io.NopCloser(strings.NewReader(string(patchedBody)))
	response.ContentLength = int64(len(patchedBody))
	response.Header.Set("Content-Length", strconv.Itoa(len(patchedBody)))
	response.Header.Del("ETag")
	response.Header.Del("Content-MD5")
	response.Header.Del("Digest")
	return nil
}

func newHandler(upstream *url.URL) http.Handler {
	proxy := httputil.NewSingleHostReverseProxy(upstream)
	director := proxy.Director
	proxy.Director = func(request *http.Request) {
		request.URL.Path = normalizePath(request.URL.Path)
		request.URL.RawPath = ""
		director(request)
		request.URL.RawQuery = normalizeQuery(request.URL.Query()).Encode()
	}
	proxy.ModifyResponse = patchItemDetailResponse
	proxy.FlushInterval = -1
	proxy.ErrorHandler = func(writer http.ResponseWriter, request *http.Request, err error) {
		log.Printf("proxy error for %s %s: %v", request.Method, request.URL.Path, err)
		http.Error(writer, "Remux is unavailable", http.StatusBadGateway)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "text/plain; charset=utf-8")
		writer.WriteHeader(http.StatusOK)
		_, _ = writer.Write([]byte("ok\n"))
	})
	mux.Handle("/", proxy)
	return mux
}

func main() {
	upstreamValue := os.Getenv("UPSTREAM_URL")
	if upstreamValue == "" {
		upstreamValue = "http://remux:3000"
	}
	upstream, err := url.Parse(upstreamValue)
	if err != nil || upstream.Scheme == "" || upstream.Host == "" {
		log.Fatalf("invalid UPSTREAM_URL %q", upstreamValue)
	}

	listenAddress := os.Getenv("LISTEN_ADDR")
	if listenAddress == "" {
		listenAddress = ":8097"
	}

	server := &http.Server{
		Addr:              listenAddress,
		Handler:           newHandler(upstream),
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}

	shutdownContext, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	go func() {
		<-shutdownContext.Done()
		context, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := server.Shutdown(context); err != nil {
			log.Printf("graceful shutdown failed: %v", err)
		}
	}()

	log.Printf("listening on %s and forwarding to %s", listenAddress, upstream.Redacted())
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
