// Command air-sdk-downloader downloads and extracts the latest AIR SDK from Harman.
package main

import (
	"archive/zip"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

const baseURL = "https://airsdk.harman.com"
const defaultUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"

type configResponse struct {
	ID            int `json:"id"`
	LatestVersion struct {
		VersionName string            `json:"versionName"`
		Links       map[string]string `json:"links"`
	} `json:"latestVersion"`
}

func main() {
	targetDir := flag.String("dir", "./sdk", "target SDK directory")
	flex := flag.Bool("flex", false, "download AIR SDK with Flex instead of AIR SDK without Flex")
	platform := flag.String("os", "", "target OS: linux, mac, windows; defaults to current OS")
	userAgent := flag.String("user-agent", defaultUserAgent, "User-Agent header")
	flag.Parse()

	if err := run(*targetDir, *flex, *platform, *userAgent); err != nil {
		fmt.Fprintln(os.Stderr, "air-sdk-downloader:", err)
		os.Exit(1)
	}
}

func run(targetDir string, flex bool, platform string, userAgent string) error {
	jar, err := cookiejar.New(nil)
	if err != nil {
		return err
	}
	client := &http.Client{Jar: jar}

	fmt.Println("Fetching AIR SDK metadata...")
	config, err := fetchConfig(client, userAgent)
	if err != nil {
		return err
	}

	linkKey, err := downloadLinkKey(flex, platform)
	if err != nil {
		return err
	}
	linkPath, ok := config.LatestVersion.Links[linkKey]
	if !ok {
		return fmt.Errorf("download link %q not found for AIR SDK %s", linkKey, config.LatestVersion.VersionName)
	}

	downloadURL := fmt.Sprintf("%s%s?id=%d", baseURL, linkPath, config.ID)
	zipPath := filepath.Join(os.TempDir(), "airsdk-"+linkKey+".zip")
	defer os.Remove(zipPath)

	fmt.Println("Downloading AIR SDK", config.LatestVersion.VersionName)
	fmt.Println(downloadURL)
	if err := downloadFile(client, zipPath, downloadURL, userAgent); err != nil {
		return err
	}

	fmt.Println("Extracting to", targetDir)
	if err := unzip(zipPath, targetDir); err != nil {
		return err
	}

	fmt.Println("Done.")
	return nil
}

func fetchConfig(client *http.Client, userAgent string) (*configResponse, error) {
	req, err := http.NewRequest(http.MethodGet, baseURL+"/api/config-settings/download", nil)
	if err != nil {
		return nil, err
	}
	setBrowserHeaders(req, userAgent)

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("config request failed: %s", resp.Status)
	}

	var config configResponse
	if err := json.NewDecoder(resp.Body).Decode(&config); err != nil {
		return nil, err
	}
	return &config, nil
}

func downloadLinkKey(flex bool, platform string) (string, error) {
	if platform == "" {
		platform = runtime.GOOS
	}

	var suffix string
	switch strings.ToLower(platform) {
	case "linux":
		suffix = "LIN"
	case "darwin", "mac":
		suffix = "MAC"
	case "windows", "win":
		suffix = "WIN"
	default:
		return "", fmt.Errorf("unsupported OS %q", platform)
	}

	prefix := "SDK_AS_"
	if flex {
		prefix = "SDK_FLEX_"
	}
	return prefix + suffix, nil
}

func setBrowserHeaders(req *http.Request, userAgent string) {
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "*/*")
	req.Header.Set("Referer", baseURL)
}

func downloadFile(client *http.Client, path string, url string, userAgent string) error {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	setBrowserHeaders(req, userAgent)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed: %s", resp.Status)
	}

	out, err := os.Create(path)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func unzip(src string, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()

	cleanDest := filepath.Clean(dest)
	if err := os.MkdirAll(cleanDest, 0755); err != nil {
		return err
	}

	for _, f := range r.File {
		path := filepath.Join(cleanDest, f.Name)
		if !strings.HasPrefix(path, cleanDest+string(os.PathSeparator)) {
			return errors.New("zip contains an illegal file path")
		}

		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(path, f.Mode()); err != nil {
				return err
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			return err
		}

		if err := extractFile(f, path); err != nil {
			return err
		}
	}

	return nil
}

func extractFile(f *zip.File, path string) error {
	in, err := f.Open()
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, f.Mode())
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}
