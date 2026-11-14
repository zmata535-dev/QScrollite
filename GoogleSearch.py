#!/usr/bin/env python3
"""Fetch Google Search HTML with curl and extract a server-rendered answer."""

import json
import re
import subprocess
import sys
from html.parser import HTMLParser
from urllib.parse import urlencode


VOID_TAGS = {
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link",
    "meta", "param", "source", "track", "wbr",
}
IGNORED_TAGS = {"script", "style", "noscript", "svg"}


class Element:
    def __init__(self, tag, attrs=None, parent=None):
        self.tag = tag
        self.attrs = dict(attrs or [])
        self.parent = parent
        self.children = []

    def text(self):
        parts = []
        for child in self.children:
            parts.append(child.text() if isinstance(child, Element) else child)
        return re.sub(r"\s+", " ", " ".join(parts)).strip()

    def elements(self):
        yield self
        for child in self.children:
            if isinstance(child, Element):
                yield from child.elements()


class SearchParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Element("root")
        self.stack = [self.root]
        self.ignored = 0

    def handle_starttag(self, tag, attrs):
        if tag in IGNORED_TAGS:
            self.ignored += 1
            return
        if self.ignored:
            return
        node = Element(tag, attrs, self.stack[-1])
        self.stack[-1].children.append(node)
        if tag not in VOID_TAGS:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        if not self.ignored and tag not in IGNORED_TAGS:
            self.stack[-1].children.append(Element(tag, attrs, self.stack[-1]))

    def handle_endtag(self, tag):
        if tag in IGNORED_TAGS:
            if self.ignored:
                self.ignored -= 1
            return
        if self.ignored:
            return
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                break

    def handle_data(self, data):
        if not self.ignored and data.strip():
            self.stack[-1].children.append(data)


def emit(ok, title="", text="", message=""):
    print(json.dumps({"ok": ok, "title": title, "text": text, "message": message}, ensure_ascii=False))


def extract_answer(html):
    parser = SearchParser()
    parser.feed(html)
    nodes = list(parser.root.elements())
    page_text = parser.root.text()
    lowered_page = page_text.lower()

    if (
        "please click here if you are not redirected" in lowered_page
        or "trouble accessing google search" in lowered_page
        or "emsg=sg_rel" in html.lower()
    ):
        return None, "Google returned a JavaScript verification/redirect page to curl; it did not include an answer."

    candidates = []
    for node in nodes:
        text = node.text()
        if len(text) < 35:
            continue
        attrs = {str(k).lower(): str(v or "").lower() for k, v in node.attrs.items()}
        marker = " ".join((attrs.get("class", ""), attrs.get("id", ""), attrs.get("data-attrid", ""), attrs.get("aria-label", "")))

        score = 0
        title = "Google featured answer"
        if "ai overview" in marker or "aioverview" in marker or "ai-overview" in marker:
            score, title = 120, "Google AI Overview"
        elif "ai overview" in text.lower() and len(text) >= 100:
            score, title = 110, "Google AI Overview"
        elif "featured-snippet" in marker or "featured snippet" in marker or "featured_snippet" in marker:
            score, title = 100, "Google featured answer"
        elif "wa:/description" in marker or "definition" in marker:
            score, title = 90, "Google featured answer"
        elif any(token in marker for token in ("hgkelc", "lgojhe", "iz6rdc", "kp-wholepage")):
            score, title = 75, "Google answer"
        elif "mjjyud" in attrs.get("class", ""):
            score, title = 20, "Top Google result"

        if score and 35 <= len(text) <= 3500:
            # Favor the tightest answer container when nested elements carry
            # the same AI/featured-result marker.
            candidates.append((score, -len(text), title, text))

    if not candidates:
        return None, "Google's answer is not present in the HTML curl received. Open Google Search to view the live result."

    candidates.sort(reverse=True)
    _, _, title, text = candidates[0]
    return (title, text[:3000]), ""


def main():
    query = " ".join(sys.argv[1:]).strip()
    if not query:
        emit(False, message="Enter a search value first.")
        return 2

    url = "https://www.google.com/search?" + urlencode({"hl": "en", "q": query})
    command = [
        "curl", "--location", "--silent", "--show-error", "--compressed",
        "--max-time", "20",
        "--user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
        "--header", "Accept-Language: en-US,en;q=0.9",
        url,
    ]
    try:
        response = subprocess.run(command, capture_output=True, text=True, timeout=23)
    except (OSError, subprocess.TimeoutExpired) as error:
        emit(False, message="curl could not fetch Google Search: " + str(error))
        return 1

    if response.returncode != 0:
        emit(False, message=(response.stderr.strip() or "curl could not fetch Google Search."))
        return response.returncode or 1

    answer, message = extract_answer(response.stdout)
    if answer:
        emit(True, title=answer[0], text=answer[1])
        return 0
    emit(False, message=message)
    return 0


if __name__ == "__main__":
    sys.exit(main())
