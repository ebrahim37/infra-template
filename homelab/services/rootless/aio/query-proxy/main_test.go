package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestNormalizeQuery(t *testing.T) {
	input := url.Values{
		"parentid":          {"library-id"},
		"includeitemtypes":  {"movie"},
		"genreids":          {"one", "two"},
		"unrecognized_name": {"untouched"},
	}

	got := normalizeQuery(input)
	if got.Get("ParentId") != "library-id" {
		t.Fatalf("ParentId = %q", got.Get("ParentId"))
	}
	if got.Get("IncludeItemTypes") != "movie" {
		t.Fatalf("IncludeItemTypes = %q", got.Get("IncludeItemTypes"))
	}
	if len(got["GenreIds"]) != 2 {
		t.Fatalf("GenreIds = %#v", got["GenreIds"])
	}
	if got.Get("unrecognized_name") != "untouched" {
		t.Fatalf("unknown parameter was changed: %#v", got)
	}
	if got.Has("parentid") || got.Has("includeitemtypes") || got.Has("genreids") {
		t.Fatalf("lowercase aliases were retained: %#v", got)
	}
}

func TestCanonicalSpellingWins(t *testing.T) {
	got := normalizeQuery(url.Values{
		"ParentId": {"canonical"},
		"parentid": {"lowercase"},
	})
	if values := got["ParentId"]; len(values) != 1 || values[0] != "canonical" {
		t.Fatalf("ParentId = %#v", values)
	}
}

func TestProxyNormalizesAndForwards(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/items" {
			t.Errorf("upstream path = %q", request.URL.Path)
		}
		if request.URL.Query().Get("ParentId") != "library-id" {
			t.Errorf("upstream query = %q", request.URL.RawQuery)
		}
		if request.Header.Get("Range") != "bytes=10-20" {
			t.Errorf("Range = %q", request.Header.Get("Range"))
		}
		body, err := io.ReadAll(request.Body)
		if err != nil {
			t.Fatal(err)
		}
		if string(body) != "request body" {
			t.Errorf("body = %q", body)
		}
		writer.Header().Set("Content-Range", "bytes 10-20/100")
		writer.WriteHeader(http.StatusPartialContent)
		_, _ = writer.Write([]byte("response body"))
	}))
	defer upstream.Close()

	upstreamURL, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}
	proxy := httptest.NewServer(newHandler(upstreamURL))
	defer proxy.Close()

	request, err := http.NewRequest(http.MethodPost, proxy.URL+"/items/?parentid=library-id", strings.NewReader("request body"))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Range", "bytes=10-20")
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusPartialContent {
		t.Fatalf("status = %d", response.StatusCode)
	}
	if response.Header.Get("Content-Range") != "bytes 10-20/100" {
		t.Fatalf("Content-Range = %q", response.Header.Get("Content-Range"))
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	if string(body) != "response body" {
		t.Fatalf("body = %q", body)
	}
}

func TestProxyAddsTopLevelMediaStreamsToItemDetail(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.Header().Set("ETag", "upstream-body-tag")
		_, _ = writer.Write([]byte(`{
			"Id":"movie-id",
			"Type":"Movie",
			"MediaSources":[{
				"Id":"source-id",
				"MediaStreams":[{"Type":"Video","Codec":"h264"}]
			}]
		}`))
	}))
	defer upstream.Close()
	upstreamURL, _ := url.Parse(upstream.URL)

	proxy := httptest.NewServer(newHandler(upstreamURL))
	defer proxy.Close()
	response, err := http.Get(proxy.URL + "/Items/movie-id?userid=user-id")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()

	var item struct {
		MediaStreams []struct {
			Type  string
			Codec string
		}
	}
	if err := json.NewDecoder(response.Body).Decode(&item); err != nil {
		t.Fatal(err)
	}
	if len(item.MediaStreams) != 1 || item.MediaStreams[0].Type != "Video" || item.MediaStreams[0].Codec != "h264" {
		t.Fatalf("MediaStreams = %#v", item.MediaStreams)
	}
	if response.Header.Get("ETag") != "" {
		t.Fatalf("stale ETag was retained: %q", response.Header.Get("ETag"))
	}
}

func TestProxyAddsEmptyMediaStreamsWhenFirstSourceHasNone(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"Id":"movie-id","MediaSources":[{"Id":"source-id"}]}`))
	}))
	defer upstream.Close()
	upstreamURL, _ := url.Parse(upstream.URL)

	response := httptest.NewRecorder()
	newHandler(upstreamURL).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/Items/movie-id", nil))

	var item map[string]json.RawMessage
	if err := json.Unmarshal(response.Body.Bytes(), &item); err != nil {
		t.Fatal(err)
	}
	if string(item["MediaStreams"]) != "[]" {
		t.Fatalf("MediaStreams = %s", item["MediaStreams"])
	}
}

func TestProxyPreservesExistingTopLevelMediaStreams(t *testing.T) {
	upstreamBody := `{"Id":"movie-id","MediaStreams":[{"Type":"Audio"}],"MediaSources":[{"MediaStreams":[]}]}`
	upstream := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(upstreamBody))
	}))
	defer upstream.Close()
	upstreamURL, _ := url.Parse(upstream.URL)

	response := httptest.NewRecorder()
	newHandler(upstreamURL).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/Items/movie-id", nil))
	if response.Body.String() != upstreamBody {
		t.Fatalf("existing response was changed: %s", response.Body.String())
	}
}

func TestHealthEndpointDoesNotReachUpstream(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("health request reached upstream")
	}))
	defer upstream.Close()
	upstreamURL, _ := url.Parse(upstream.URL)

	response := httptest.NewRecorder()
	newHandler(upstreamURL).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if response.Code != http.StatusOK || response.Body.String() != "ok\n" {
		t.Fatalf("health response = %d %q", response.Code, response.Body.String())
	}
}
