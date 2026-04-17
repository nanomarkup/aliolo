#!/usr/bin/env python3
import html
import html.parser
import sys
import urllib.request


class ImageParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag != "img":
            return
        data = dict(attrs)
        alt = html.unescape(data.get("alt", "")).strip()
        src = html.unescape(data.get("src", "")).strip()
        if alt and src:
            self.images.append((alt, src))


def main() -> int:
    url = "https://www.novatr.com/blog/impressive-bridges-in-the-world"
    request = urllib.request.Request(url, headers={"User-Agent": "Aliolo media sync"})
    with urllib.request.urlopen(request, timeout=30) as response:
        text = response.read().decode("utf-8", "ignore")

    parser = ImageParser()
    parser.feed(text)
    keywords = ("bridge", "viaduct", "gard", "cirkelbroen", "root")
    for alt, src in parser.images:
        if any(keyword in alt.lower() for keyword in keywords):
            print(f"{alt}\t{src}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
