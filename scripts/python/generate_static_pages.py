#!/usr/bin/env python3
import os
import json
import re
from pathlib import Path

# Supported languages
SUPPORTED_LANGUAGES = [
    "en", "id", "bg", "cs", "da", "de", "et", "es", "fr", "ga", "hr", "it", "lv", "lt", 
    "hu", "mt", "nl", "pl", "pt", "ro", "sk", "sl", "fi", "sv", "tl", "vi", "tr", "el", 
    "uk", "ar", "hi", "zh", "ja", "ko"
]

# Language display names (native names/endonyms where possible)
LANGUAGE_DISPLAY_NAMES = {
    "en": "English",
    "id": "Bahasa Indonesia",
    "bg": "Български",
    "cs": "Čeština",
    "da": "Dansk",
    "de": "Deutsch",
    "et": "Eesti",
    "es": "Español",
    "fr": "Français",
    "ga": "Gaeilge",
    "hr": "Hrvatski",
    "it": "Italiano",
    "lv": "Latviešu",
    "lt": "Lietuvių",
    "hu": "Magyar",
    "mt": "Malti",
    "nl": "Nederlands",
    "pl": "Polski",
    "pt": "Português",
    "ro": "Română",
    "sk": "Slovenčina",
    "sl": "Slovenščina",
    "fi": "Suomi",
    "sv": "Svenska",
    "tl": "Tagalog",
    "vi": "Tiếng Việt",
    "tr": "Türkçe",
    "el": "Ελληνικά",
    "uk": "Українська",
    "ar": "العربية",
    "hi": "हिन्दी",
    "zh": "中文",
    "ja": "日本語",
    "ko": "한국어"
}

def render_lang_switcher(lang: str, page: str) -> str:
    lang_options = []
    for l in SUPPORTED_LANGUAGES:
        if l == "en":
            prefix = ""
        else:
            prefix = f"/{l}"
            
        if page == "landing":
            url = prefix if prefix else "/"
        else:
            url = f"{prefix}/{page}"
            
        selected = " selected" if l == lang else ""
        disp_name = LANGUAGE_DISPLAY_NAMES.get(l, l.upper())
        lang_options.append(f'<option value="{url}" data-lang="{l}"{selected}>{disp_name}</option>')
        
    return f"""<select class="lang-select" onchange="document.cookie='aliolo_lang=' + this.options[this.selectedIndex].getAttribute('data-lang') + '; path=/; max-age=31536000; SameSite=Lax; Secure'; window.location.href=this.value" aria-label="Change language">
      {"".join(lang_options)}
    </select>"""

# Legal layout CSS styles
LEGAL_STYLES = """
  :root {
    color-scheme: light;
    --ink: #112034;
    --muted: #5f6c81;
    --brand: #175f90;
    --brand-strong: #0d476d;
    --accent: #d67a2d;
    --accent-soft: rgba(214, 122, 45, 0.12);
    --surface: rgba(255, 255, 255, 0.96);
    --page: #eef4f7;
    --line: rgba(17, 32, 52, 0.10);
    --line-strong: rgba(23, 95, 144, 0.18);
    --shadow: 0 22px 58px rgba(17, 32, 52, 0.08);
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    color: var(--ink);
    font-family: "Source Sans 3", system-ui, -apple-system, sans-serif;
    line-height: 1.6;
    background:
      radial-gradient(circle at top left, rgba(23, 95, 144, 0.11), transparent 28rem),
      radial-gradient(circle at top right, rgba(214, 122, 45, 0.10), transparent 24rem),
      linear-gradient(180deg, #f9fcfd 0%, var(--page) 100%);
  }
  a { color: var(--brand); font-weight: 700; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .shell { width: min(1100px, calc(100% - 40px)); margin: 0 auto; }
  h1, h2, h3, p, li, .subtitle, .meta, .content {
    overflow-wrap: anywhere;
    word-break: normal;
  }
  header {
    position: sticky;
    top: 0;
    z-index: 20;
    padding: 20px 0;
    backdrop-filter: blur(18px);
    background: rgba(249, 252, 253, 0.88);
    border-bottom: 1px solid rgba(17, 32, 52, 0.06);
  }
  .brand {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
    flex-wrap: wrap;
  }
  .brand-name {
    display: inline-flex;
    align-items: center;
    gap: 12px;
    font-family: "Manrope", system-ui, -apple-system, sans-serif;
    font-size: 27px;
    font-weight: 800;
    line-height: 1;
    letter-spacing: -0.04em;
    color: var(--brand);
    text-transform: lowercase;
  }
  .brand-name:hover { text-decoration: none; }
  .brand-name img {
    width: 46px;
    height: 46px;
  }
  nav { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
  nav a {
    color: var(--ink);
    font-size: 15px;
    font-weight: 600;
    padding: 10px 14px;
    border: 1px solid transparent;
    border-radius: 999px;
    transition: background 0.18s ease, border-color 0.18s ease, transform 0.18s ease;
  }
  nav a:hover {
    border-color: var(--line);
    background: rgba(255, 255, 255, 0.84);
    transform: translateY(-1px);
    text-decoration: none;
  }
  nav a.active {
    border-color: var(--line-strong);
    background: rgba(23, 95, 144, 0.08);
    color: var(--brand);
    text-decoration: none;
  }
  .lang-select {
    font-family: inherit;
    font-size: 14px;
    font-weight: 600;
    min-height: 44px;
    padding: 6px 32px 6px 12px;
    border: 1px solid var(--line);
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.84) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23175f90' stroke-width='2.5'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M19.5 8.25l-7.5 7.5-7.5-7.5'/%3E%3C/svg%3E") no-repeat right 10px center;
    background-size: 14px;
    color: var(--ink);
    cursor: pointer;
    outline: none;
    transition: border-color 0.18s ease, background-color 0.18s ease;
    appearance: none;
    -webkit-appearance: none;
  }
  .lang-select:hover {
    border-color: var(--brand);
    background-color: rgba(255, 255, 255, 0.96);
  }
  main { padding: 34px 0 78px; }
  .hero {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 290px;
    gap: 28px;
    align-items: stretch;
    margin-bottom: 28px;
  }
  .hero > * { min-width: 0; }
  h1 {
    margin: 0;
    font-family: "Manrope", system-ui, sans-serif;
    font-size: clamp(34px, 5vw, 52px);
    font-weight: 800;
    line-height: 1.02;
    letter-spacing: -0.05em;
    color: var(--ink);
  }
  .subtitle {
    margin: 14px 0 0;
    color: var(--muted);
    font-size: 18px;
    max-width: 760px;
  }
  .eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 14px;
    padding: 8px 12px;
    border-radius: 999px;
    background: rgba(23, 95, 144, 0.10);
    color: var(--brand);
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }
  .meta {
    padding: 22px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 24px;
    font-size: 14px;
    color: var(--muted);
    box-shadow: var(--shadow);
    min-width: 0;
    max-width: 100%;
  }
  .meta strong { color: var(--ink); font-weight: 600; }
  .content {
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 28px;
    padding: clamp(24px, 4vw, 48px);
    box-shadow: var(--shadow);
  }
  h2 {
    margin: 34px 0 12px;
    font-family: "Manrope", system-ui, sans-serif;
    font-size: 24px;
    font-weight: 800;
    line-height: 1.1;
    letter-spacing: -0.03em;
    color: var(--ink);
  }
  h2:first-child { margin-top: 0; }
  p { margin: 12px 0; font-size: 17px; }
  ul { padding-left: 24px; margin: 12px 0; }
  li { margin: 8px 0; font-size: 17px; }
  .notice {
    margin: 24px 0;
    padding: 18px 20px;
    border-radius: 18px;
    background: rgba(23, 95, 144, 0.06);
    border: 1px solid rgba(23, 95, 144, 0.10);
    color: var(--ink);
    font-size: 14px;
  }
  .plans {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
    margin: 24px 0;
  }
  .plan {
    padding: 26px;
    border: 1px solid var(--line);
    border-radius: 24px;
    background: rgba(255, 255, 255, 0.96);
    box-shadow: 0 16px 34px rgba(17, 32, 52, 0.05);
  }
  .plan h2 { margin-top: 0; color: var(--ink); font-size: 22px; }
  .price {
    font-family: "Manrope", system-ui, sans-serif;
    font-size: 38px;
    font-weight: 800;
    color: var(--brand);
    margin: 8px 0 16px;
    letter-spacing: -0.05em;
  }
  .tag {
    display: inline-flex;
    margin-bottom: 12px;
    padding: 6px 11px;
    border-radius: 999px;
    background: var(--accent-soft);
    color: var(--accent);
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .comparison-card {
    margin-top: 28px;
    padding: 28px;
    border-radius: 28px;
    border: 1px solid var(--line);
    background: rgba(255, 255, 255, 0.96);
    box-shadow: 0 16px 34px rgba(17, 32, 52, 0.05);
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    max-width: 100%;
  }
  .comparison-card h2 {
    margin-top: 0;
  }
  .comparison-card p {
    color: var(--muted);
  }
  .comparison-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 18px;
    table-layout: fixed;
  }
  .comparison-table th,
  .comparison-table td {
    padding: 14px 10px;
    border-bottom: 1px solid var(--line);
    text-align: center;
    font-size: 15px;
    overflow-wrap: anywhere;
  }
  .comparison-table th:first-child,
  .comparison-table td:first-child {
    text-align: left;
    width: 52%;
  }
  .comparison-table th {
    color: var(--muted);
    font-weight: 700;
  }
  .comparison-table td:first-child {
    color: var(--ink);
    font-weight: 600;
  }
  .comparison-table tr:last-child td {
    border-bottom: none;
  }
  .comparison-check {
    color: var(--brand);
    font-weight: 800;
    font-size: 18px;
  }
  .comparison-check.pro {
    color: #0f9d58;
  }
  .comparison-cross {
    color: #c4ccd8;
    font-weight: 800;
    font-size: 18px;
  }
  .comparison-note {
    margin-top: 18px;
    color: var(--muted);
    font-size: 15px;
  }
  @media (max-width: 760px) {
    .shell { width: min(100% - 28px, 1100px); }
    header { padding: 16px 0; }
    .hero, .plans { grid-template-columns: 1fr; }
    .hero { gap: 16px; }
    nav { gap: 6px; }
    nav a { padding: 9px 12px; }
    main { padding-top: 24px; }
    h1 { font-size: clamp(32px, 12vw, 44px); }
    .subtitle { font-size: 16px; }
    .hero { grid-template-columns: minmax(0, 1fr); }
    .comparison-card { padding: 20px; }
    .comparison-table th,
    .comparison-table td {
      padding: 12px 8px;
      font-size: 14px;
    }
  }
"""

# Checkout Page CSS styles
PAY_STYLES = """
    :root {
      color-scheme: light;
      --ink: #122338;
      --muted: #5f6f85;
      --brand: #185f90;
      --brand-strong: #0d476d;
      --accent: #d97728;
      --line: rgba(18, 35, 56, 0.12);
      --surface: rgba(255, 255, 255, 0.96);
      --page: #eef5f8;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: "Source Sans 3", system-ui, -apple-system, sans-serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(24, 95, 144, 0.10), transparent 28rem),
        radial-gradient(circle at top right, rgba(217, 119, 40, 0.10), transparent 24rem),
        linear-gradient(180deg, #f9fcfd 0%, var(--page) 100%);
    }
    a { color: var(--brand); text-decoration: none; font-weight: 700; }
    a:hover { text-decoration: underline; }
    .shell {
      width: min(1100px, calc(100% - 32px));
      margin: 0 auto;
    }
    header {
      padding: 22px 0;
      border-bottom: 1px solid rgba(18, 35, 56, 0.06);
      background: rgba(249, 252, 253, 0.88);
      backdrop-filter: blur(14px);
    }
    .brand {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      flex-wrap: wrap;
    }
    .brand-name {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      color: var(--brand);
      font-family: "Manrope", system-ui, sans-serif;
      font-size: 27px;
      font-weight: 800;
      letter-spacing: -0.04em;
      text-transform: lowercase;
    }
    .brand-name:hover { text-decoration: none; }
    .brand-name img {
      width: 44px;
      height: 44px;
    }
    nav {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    nav a {
      color: var(--ink);
      font-size: 15px;
      font-weight: 600;
      padding: 10px 14px;
      border-radius: 999px;
      border: 1px solid transparent;
    }
    nav a:hover {
      background: rgba(255, 255, 255, 0.84);
      border-color: var(--line);
      text-decoration: none;
    }
    main {
      padding: 42px 0 72px;
    }
    .layout {
      display: grid;
      grid-template-columns: minmax(0, 0.92fr) minmax(320px, 0.78fr);
      gap: 24px;
      align-items: start;
    }
    .card {
      padding: 28px;
      border-radius: 28px;
      border: 1px solid var(--line);
      background: var(--surface);
      box-shadow: 0 24px 54px rgba(18, 35, 56, 0.08);
    }
    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 16px;
      padding: 8px 12px;
      border-radius: 999px;
      background: rgba(24, 95, 144, 0.10);
      color: var(--brand);
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    h1 {
      margin: 0 0 12px;
      font-family: "Manrope", system-ui, sans-serif;
      font-size: clamp(34px, 5vw, 52px);
      line-height: 1.02;
      letter-spacing: -0.04em;
    }
    p {
      margin: 0 0 14px;
      color: var(--muted);
      font-size: 17px;
      line-height: 1.6;
    }
    .status {
      margin-top: 22px;
      padding: 18px 20px;
      border-radius: 18px;
      background: rgba(24, 95, 144, 0.06);
      border: 1px solid rgba(24, 95, 144, 0.12);
      color: var(--ink);
      font-size: 15px;
    }
    .status strong { color: var(--brand); }
    .status.error {
      background: rgba(217, 119, 40, 0.10);
      border-color: rgba(217, 119, 40, 0.16);
    }
    .list {
      display: grid;
      gap: 14px;
      margin-top: 20px;
    }
    .list div {
      padding: 16px 18px;
      border-radius: 18px;
      background: rgba(255, 255, 255, 0.92);
      border: 1px solid var(--line);
    }
    .list strong {
      display: block;
      margin-bottom: 6px;
      color: var(--ink);
      font-size: 15px;
    }
    .checkout-shell {
      min-height: 560px;
      display: grid;
      align-content: start;
      gap: 18px;
    }
    .checkout-target {
      min-height: 450px;
    }
    .fallback {
      display: none;
      padding: 20px;
      border-radius: 20px;
      border: 1px dashed rgba(24, 95, 144, 0.24);
      background: rgba(24, 95, 144, 0.04);
      color: var(--muted);
      font-size: 15px;
    }
    .fallback.visible {
      display: block;
    }
    .links {
      display: flex;
      gap: 14px;
      flex-wrap: wrap;
      margin-top: 10px;
    }
    .links a {
      color: var(--muted);
      font-weight: 600;
    }
    .lang-select {
      font-family: inherit;
      font-size: 14px;
      font-weight: 600;
      min-height: 44px;
      padding: 6px 32px 6px 12px;
      border: 1px solid var(--line);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.84) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23175f90' stroke-width='2.5'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M19.5 8.25l-7.5 7.5-7.5-7.5'/%3E%3C/svg%3E") no-repeat right 10px center;
      background-size: 14px;
      color: var(--ink);
      cursor: pointer;
      outline: none;
      transition: border-color 0.18s ease, background-color 0.18s ease;
      appearance: none;
      -webkit-appearance: none;
    }
    .lang-select:hover {
      border-color: var(--brand);
      background-color: rgba(255, 255, 255, 0.96);
    }
    @media (max-width: 920px) {
      .layout {
        grid-template-columns: 1fr;
      }
    }
"""

# Landing Page CSS styles
LANDING_STYLES = """
  :root {
    color-scheme: light;
    --ink: #162235;
    --muted: #5f6f85;
    --brand: #185f90;
    --brand-strong: #0d476d;
    --accent: #d97728;
    --line: rgba(18, 34, 53, 0.10);
    --line-strong: rgba(24, 95, 144, 0.18);
    --surface: #ffffff;
    --surface-soft: #f6fbfd;
    --hero-wash: rgba(24, 95, 144, 0.08);
    --hero-wash-2: rgba(217, 119, 40, 0.09);
    --page: #eef5f8;
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    color: var(--ink);
    font-family: "Roboto", system-ui, -apple-system, sans-serif;
    line-height: 1.58;
    background:
      radial-gradient(circle at top left, var(--hero-wash), transparent 30rem),
      radial-gradient(circle at top right, var(--hero-wash-2), transparent 28rem),
      linear-gradient(180deg, #f9fcfd 0%, var(--page) 100%);
  }
  a { color: var(--brand); font-weight: 700; text-decoration: none; }
  a:hover { text-decoration: underline; }
  a:focus-visible,
  button:focus-visible {
    outline: 3px solid #f0a15d;
    outline-offset: 3px;
  }
  .skip-link {
    position: fixed;
    top: 10px;
    left: 10px;
    z-index: 100;
    padding: 10px 14px;
    border-radius: 10px;
    background: var(--ink);
    color: #fff;
    transform: translateY(-160%);
    transition: transform 0.18s ease;
  }
  .skip-link:focus { transform: translateY(0); }
  .shell { width: min(1160px, calc(100% - 40px)); margin: 0 auto; }
  header {
    padding: 14px 0;
    position: sticky;
    top: 0;
    z-index: 10;
    backdrop-filter: blur(16px);
    background: rgba(249, 252, 253, 0.88);
    border-bottom: 1px solid rgba(18, 34, 53, 0.06);
  }
  .brand {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
    flex-wrap: wrap;
  }
  .brand-name {
    display: inline-flex;
    align-items: center;
    gap: 12px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 26px;
    font-weight: 600;
    line-height: 1;
    letter-spacing: 0.03em;
    color: var(--brand);
    text-transform: lowercase;
  }
  .brand-name:hover { text-decoration: none; }
  .brand-name img {
    width: 44px;
    height: 44px;
    border-radius: 12px;
  }
  nav {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
    justify-content: flex-end;
    min-width: 0;
  }
  nav a {
    color: var(--ink);
    font-size: 14px;
    font-weight: 500;
    padding: 10px 14px;
    border-radius: 999px;
    border: 1px solid transparent;
    transition: all 0.18s ease;
  }
  nav a:hover {
    text-decoration: none;
    border-color: var(--line);
    background: rgba(255, 255, 255, 0.84);
  }
  .lang-select {
    font-family: inherit;
    font-size: 14px;
    font-weight: 600;
    min-height: 44px;
    padding: 6px 32px 6px 12px;
    border: 1px solid var(--line);
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.84) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23175f90' stroke-width='2.5'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M19.5 8.25l-7.5 7.5-7.5-7.5'/%3E%3C/svg%3E") no-repeat right 10px center;
    background-size: 14px;
    color: var(--ink);
    cursor: pointer;
    outline: none;
    transition: border-color 0.18s ease, background-color 0.18s ease;
    appearance: none;
    -webkit-appearance: none;
  }
  .lang-select:hover {
    border-color: var(--brand);
    background-color: rgba(255, 255, 255, 0.96);
  }
  .nav-cta {
    border-color: var(--line-strong);
    background: rgba(24, 95, 144, 0.08);
    color: var(--brand);
    font-weight: 700;
  }
  .nav-login { color: var(--brand); font-weight: 700; }
  h1, h2, h3, p, li, .btn, .eyebrow, .price-amount, .preview-caption, .final-cta {
    overflow-wrap: anywhere;
    word-break: normal;
  }
  main { padding: 32px 0 80px; }
  .hero {
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(320px, 0.9fr);
    gap: 34px;
    align-items: stretch;
    margin-bottom: 74px;
  }
  .hero-copy {
    padding: 56px 0 10px;
  }
  .eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    border-radius: 999px;
    background: rgba(24, 95, 144, 0.10);
    color: var(--brand);
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }
  h1 {
    margin: 18px 0 18px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: clamp(44px, 6vw, 70px);
    line-height: 0.98;
    letter-spacing: -0.05em;
    color: var(--ink);
  }
  .hero p {
    margin: 0;
    font-size: 18px;
    color: var(--muted);
    max-width: 720px;
  }
  .cta-group {
    display: flex;
    gap: 14px;
    flex-wrap: wrap;
    margin-top: 28px;
  }
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 54px;
    padding: 0 24px;
    border-radius: 16px;
    font-weight: 700;
    font-size: 15px;
    transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
    cursor: pointer;
    border: 1px solid transparent;
  }
  .btn:hover {
    transform: translateY(-1px);
    text-decoration: none;
    box-shadow: 0 12px 28px rgba(18, 34, 53, 0.10);
  }
  .btn-primary {
    background: linear-gradient(135deg, var(--brand), var(--brand-strong));
    color: #fff;
  }
  .btn-secondary {
    background: rgba(255, 255, 255, 0.82);
    color: var(--ink);
    border-color: var(--line);
  }
  .proof-row {
    display: flex;
    gap: 22px;
    flex-wrap: wrap;
    margin-top: 28px;
  }
  .proof {
    min-width: 150px;
  }
  .proof strong {
    display: block;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 28px;
    line-height: 1;
    letter-spacing: -0.04em;
    color: var(--brand);
  }
  .proof span {
    display: block;
    margin-top: 8px;
    color: var(--muted);
    font-size: 13px;
  }
  .hero-panel {
    position: relative;
    padding: 14px;
    border-radius: 30px;
    background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(243,249,252,0.98));
    border: 1px solid var(--line);
    box-shadow: 0 30px 70px rgba(18, 34, 53, 0.10);
    overflow: hidden;
  }
  .hero-panel::before {
    content: "";
    position: absolute;
    inset: -80px auto auto -80px;
    width: 210px;
    height: 210px;
    border-radius: 50%;
    background: rgba(24, 95, 144, 0.08);
  }
  .panel-card {
    position: relative;
    background: #fff;
    border: 1px solid var(--line);
    border-radius: 24px;
    padding: 22px;
    margin-bottom: 16px;
  }
  .panel-card:last-child { margin-bottom: 0; }
  .product-preview {
    margin: 0;
    position: relative;
    min-height: 100%;
    display: flex;
    flex-direction: column;
  }
  .product-preview img {
    width: 100%;
    height: auto;
    aspect-ratio: 16 / 9;
    object-fit: cover;
    border-radius: 20px;
    border: 1px solid var(--line);
  }
  .preview-caption {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 18px;
    padding: 18px 10px 8px;
  }
  .preview-caption strong {
    display: block;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 17px;
  }
  .preview-caption span {
    display: block;
    color: var(--muted);
    font-size: 14px;
    margin-top: 3px;
  }
  .preview-chip {
    flex: 0 0 auto;
    padding: 7px 10px;
    border-radius: 999px;
    background: rgba(24, 95, 144, 0.1);
    color: var(--brand);
    font-size: 12px;
    font-weight: 800;
  }
  .panel-label {
    color: var(--accent);
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }
  .panel-card h3 {
    margin: 10px 0 8px;
    font-size: 22px;
    font-family: "Poppins", system-ui, sans-serif;
    line-height: 1.1;
  }
  .panel-card p {
    margin: 0 0 14px;
    font-size: 14px;
    color: var(--muted);
  }
  .micro-list {
    display: grid;
    gap: 10px;
  }
  .micro-list span {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    color: var(--ink);
    font-size: 14px;
  }
  .micro-list span::before {
    content: "•";
    color: var(--brand);
    font-weight: 900;
  }
  .section {
    margin-bottom: 74px;
  }
  .section-heading {
    max-width: 720px;
    margin-bottom: 26px;
  }
  .section-heading h2 {
    margin: 0 0 10px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: clamp(28px, 4vw, 40px);
    line-height: 1.05;
    letter-spacing: -0.04em;
  }
  .section-heading p {
    margin: 0;
    color: var(--muted);
    font-size: 17px;
  }
  .feature-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
  }
  .feature-card {
    background: rgba(255, 255, 255, 0.92);
    padding: 26px;
    border-radius: 26px;
    border: 1px solid var(--line);
    box-shadow: 0 16px 34px rgba(18, 34, 53, 0.05);
  }
  .feature-card h3 {
    margin: 16px 0 8px;
    font-size: 21px;
    font-family: "Poppins", system-ui, sans-serif;
  }
  .feature-card p {
    margin: 0;
    color: var(--muted);
    font-size: 15px;
  }
  .feature-icon {
    width: 46px;
    height: 46px;
    border-radius: 14px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: rgba(24, 95, 144, 0.10);
    color: var(--brand);
  }
  .feature-icon svg {
    width: 24px;
    height: 24px;
    fill: none;
    stroke: currentColor;
    stroke-width: 1.9;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
  .steps {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
  }
  .step {
    padding: 24px;
    border-radius: 24px;
    background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(240,248,251,0.96));
    border: 1px solid var(--line);
  }
  .step strong {
    display: inline-flex;
    width: 36px;
    height: 36px;
    align-items: center;
    justify-content: center;
    border-radius: 999px;
    background: var(--brand);
    color: #fff;
    font-size: 14px;
    margin-bottom: 16px;
  }
  .step h3 {
    margin: 0 0 8px;
    font-size: 20px;
    font-family: "Poppins", system-ui, sans-serif;
  }
  .step p {
    margin: 0;
    color: var(--muted);
  }
  .pricing-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
  }
  .price-card {
    padding: 28px;
    border-radius: 26px;
    background: rgba(255,255,255,0.96);
    border: 1px solid var(--line);
    position: relative;
    display: flex;
    flex-direction: column;
  }
  .price-card.featured {
    border-color: var(--line-strong);
    box-shadow: 0 18px 40px rgba(24, 95, 144, 0.12);
    transform: translateY(-4px);
  }
  .price-tag {
    display: inline-flex;
    padding: 6px 10px;
    border-radius: 999px;
    background: rgba(217, 119, 40, 0.10);
    color: var(--accent);
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .price-card h3 {
    margin: 16px 0 8px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 22px;
  }
  .price-amount {
    margin: 6px 0 12px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 38px;
    line-height: 1;
    letter-spacing: -0.05em;
    color: var(--brand);
  }
  .price-card p {
    margin: 0 0 18px;
    color: var(--muted);
  }
  .price-card ul {
    margin: 0;
    padding-left: 18px;
  }
  .price-card .btn {
    width: 100%;
    margin-top: auto;
    padding-top: 0;
    padding-bottom: 0;
  }
  .price-card li:last-child { margin-bottom: 22px; }
  .price-card li {
    color: var(--ink);
    margin: 8px 0;
  }
  .trust-panel {
    padding: 30px;
    border-radius: 28px;
    background: linear-gradient(180deg, rgba(255,255,255,0.97), rgba(245,250,252,0.97));
    border: 1px solid var(--line);
  }
  .trust-grid {
    display: grid;
    grid-template-columns: 1.15fr 0.85fr;
    gap: 28px;
    align-items: start;
  }
  .trust-panel h2 {
    margin: 0 0 10px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 32px;
    line-height: 1.08;
  }
  .trust-panel p {
    margin: 0 0 14px;
    color: var(--muted);
    font-size: 16px;
  }
  .trust-list {
    display: grid;
    gap: 12px;
    margin-top: 18px;
  }
  .trust-list div {
    padding: 14px 16px;
    border-radius: 16px;
    background: rgba(24, 95, 144, 0.06);
    border: 1px solid rgba(24, 95, 144, 0.10);
  }
  .mini-faq {
    display: grid;
    gap: 12px;
  }
  .mini-faq div {
    padding: 16px 18px;
    border-radius: 18px;
    background: #fff;
    border: 1px solid var(--line);
  }
  .mini-faq strong {
    display: block;
    margin-bottom: 6px;
    font-size: 15px;
  }
  .final-cta {
    margin-top: 22px;
    padding: 30px;
    border-radius: 26px;
    color: #fff;
    background: linear-gradient(135deg, var(--brand), var(--brand-strong));
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 24px;
  }
  .final-cta h2 {
    margin: 0 0 6px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 28px;
    line-height: 1.08;
  }
  .final-cta p { margin: 0; color: rgba(255,255,255,0.82); }
  .final-cta .btn {
    flex: 0 0 auto;
    background: #fff;
    color: var(--brand-strong);
  }
  footer {
    padding: 56px 0 64px;
    border-top: 1px solid var(--line);
    background: rgba(255,255,255,0.80);
  }
  .footer-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.2fr) minmax(320px, 0.8fr);
    gap: 34px;
    align-items: start;
  }
  .footer-brand strong {
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 22px;
    color: var(--brand);
  }
  .footer-brand p {
    margin: 10px 0 0;
    color: var(--muted);
    font-size: 14px;
    max-width: 480px;
  }
  .footer-links {
    display: flex;
    gap: 16px 20px;
    flex-wrap: wrap;
    justify-content: flex-end;
  }
  .footer-links a {
    color: var(--ink);
    font-size: 14px;
    font-weight: 500;
  }
  .legal-note {
    margin-top: 34px;
    padding-top: 24px;
    border-top: 1px solid var(--line);
    font-size: 12px;
    color: var(--muted);
    line-height: 1.6;
  }
  .legal-note strong { color: var(--ink); }
  @media (max-width: 820px) {
    .hero, .trust-grid, .footer-grid { grid-template-columns: 1fr; }
    .feature-grid, .steps, .pricing-grid { grid-template-columns: 1fr; }
    .hero-panel { display: none; }
    .footer-links { justify-content: flex-start; }
    .price-card.featured { transform: none; }
    .hero-copy { padding-top: 24px; }
  }
  @media (max-width: 960px) {
    .brand { align-items: center; }
    nav {
      width: auto;
      margin-left: auto;
      justify-content: flex-end;
    }
    .desktop-link,
    .nav-cta,
    .hero .btn-secondary {
      display: none;
    }
    .lang-select {
      max-width: 100%;
      min-height: 44px;
    }
    .nav-login {
      min-height: 44px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
    }
  }
  @media (max-width: 520px) {
    .shell { width: min(100% - 28px, 1160px); }
    header { position: static; }
    .brand { align-items: center; }
    .brand-name { font-size: 24px; }
    nav {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      width: 100%;
      gap: 8px;
    }
    .lang-select {
      width: 100%;
      min-width: 0;
    }
    .nav-login {
      width: auto;
      text-align: center;
      padding-inline: 14px;
    }
    main { padding-top: 20px; }
    .hero-copy { padding-top: 18px; }
    h1 {
      font-size: clamp(36px, 13vw, 52px);
      line-height: 1.04;
    }
    .hero p { font-size: 17px; }
    .cta-group {
      display: grid;
      grid-template-columns: 1fr;
      gap: 10px;
    }
    .cta-group .btn { width: 100%; }
    .final-cta {
      align-items: stretch;
      flex-direction: column;
    }
    .final-cta .btn { width: 100%; }
  }
"""

# HTML Layouts with placeholders
LEGAL_LAYOUT = """<!DOCTYPE html>
<html lang="{{LANG}}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{TITLE}}</title>
  <meta name="description" content="{{SUBTITLE}}">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
  <meta property="og:type" content="website">
  <meta property="og:title" content="{{TITLE}}">
  <meta property="og:description" content="{{SUBTITLE}}">
  <meta property="og:url" content="https://aliolo.com{{PREFIX}}{{PAGE_PATH}}">
  <meta property="og:image" content="https://aliolo.com/aliolo-social-preview.png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="Aliolo visual learning cards and spaced repetition preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{{TITLE}}">
  <meta name="twitter:description" content="{{SUBTITLE}}">
  <meta name="twitter:image" content="https://aliolo.com/aliolo-social-preview.png">
  <link rel="canonical" href="https://aliolo.com{{PREFIX}}{{PAGE_PATH}}">
{{SEO_ALTERNATES}}
{{STRUCTURED_DATA_HTML}}
  <link rel="icon" type="image/webp" href="/app_icon.webp">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=Source+Sans+3:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>{{LEGAL_STYLES}</style>
</head>
<body>
  <header>
    <div class="shell brand">
      <a class="brand-name" href="{{HOME_URL}}" aria-label="Aliolo home">
        <img src="/app_icon.webp" alt="Aliolo Logo" />
        aliolo
      </a>
      <nav aria-label="Legal page navigation">
        {{NAV_LINKS}}
        {{LANG_SWITCHER}}
      </nav>
    </div>
  </header>
  <main class="shell">
    <section class="hero">
      <div>
        <div class="eyebrow">{{LEGAL_INFO_LABEL}}</div>
        <h1>{{TITLE}}</h1>
        <p class="subtitle">{{SUBTITLE}}</p>
      </div>
      <aside class="meta">
        <strong>{{LAST_UPDATED_LABEL}}</strong><br>
        {{UPDATED_DATE}}<br><br>
        <strong>{{SUPPORT_LABEL}}</strong><br>
        <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a>
      </aside>
    </section>
    <article class="content">
      {{BODY_CONTENT}}
    </article>
  </main>
</body>
</html>"""

PAY_LAYOUT = """<!DOCTYPE html>
<html lang="{{LANG}}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{CHECKOUT_TITLE}}</title>
  <meta name="description" content="{{CHECKOUT_SUBTITLE}}">
  <meta name="robots" content="noindex,nofollow">
  <link rel="canonical" href="https://aliolo.com{{PREFIX}}/pay">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=Source+Sans+3:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>{{PAY_STYLES}</style>
  <script src="https://cdn.paddle.com/paddle/v2/paddle.js"></script>
</head>
<body>
  <header>
    <div class="shell brand">
      <a class="brand-name" href="{{HOME_URL}}" aria-label="Aliolo home">
        <img src="/app_icon.webp" alt="Aliolo logo" />
        aliolo
      </a>
      <nav aria-label="Checkout page navigation">
        <a href="{{PREFIX}}/pricing">{{PRICING_LABEL}}</a>
        <a href="{{PREFIX}}/terms">{{TERMS_LABEL}}</a>
        <a href="{{PREFIX}}/privacy">{{PRIVACY_LABEL}}</a>
        <a href="{{PREFIX}}/refund">{{REFUND_LABEL}}</a>
        {{LANG_SWITCHER}}
      </nav>
    </div>
  </header>
  <main class="shell">
    <section class="layout">
      <article class="card">
        <div class="eyebrow">{{CHECKOUT_EYEBROW}}</div>
        <h1>{{CHECKOUT_H1}}</h1>
        <p>{{CHECKOUT_SUBTITLE}}</p>
        <div class="status" id="checkout-status">
          <strong>{{CHECKOUT_STATUS_TITLE}}</strong><br>
          {{CHECKOUT_STATUS_DESC}}
        </div>
        <div class="list">
          <div>
            <strong>{{PAYMENT_SUPPORT_TITLE}}</strong>
            {{PAYMENT_SUPPORT_DESC}}
          </div>
          <div>
            <strong>{{BILLING_TITLE}}</strong>
            {{BILLING_DESC}}
          </div>
          <div>
            <strong>{{POLICY_TITLE}}</strong>
            {{POLICY_DESC}}
          </div>
        </div>
        <div class="links">
          <a href="{{PREFIX}}/pricing">{{PRICING_LABEL}}</a>
          <a href="{{PREFIX}}/terms">{{TERMS_LABEL}}</a>
          <a href="{{PREFIX}}/privacy">{{PRIVACY_LABEL}}</a>
          <a href="{{PREFIX}}/refund">{{REFUND_LABEL}}</a>
        </div>
      </article>
      <aside class="card checkout-shell">
        <div id="checkout-fallback" class="fallback">Checkout could not be started on this page. Return to Aliolo billing and try again. If the problem persists, contact <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a>.</div>
        <div id="checkout-container" class="checkout-target" aria-live="polite"></div>
      </aside>
    </section>
  </main>
  <script>
    (() => {
      const token = {{PADDLE_CLIENT_TOKEN}};
      const statusEl = document.getElementById('checkout-status');
      const fallbackEl = document.getElementById('checkout-fallback');
      const params = new URLSearchParams(window.location.search);
      const transactionId = params.get('_ptxn');

      const setStatus = (title, message, isError = false) => {
        statusEl.classList.toggle('error', isError);
        statusEl.innerHTML = '<strong>' + title + '</strong><br>' + message;
      };

      if (!token) {
        fallbackEl.classList.add('visible');
        setStatus(
          'Checkout is not configured',
          'Aliolo is missing the Paddle client-side token required for the /pay page. Add PADDLE_CLIENT_TOKEN to the Worker environment before using this checkout.',
          true,
        );
        return;
      }

      if (!transactionId) {
        fallbackEl.classList.add('visible');
        setStatus(
          'No checkout transaction found',
          'This page is meant to be opened from an Aliolo billing flow. Open billing in the app and start checkout again.',
          true,
        );
        return;
      }

      try {
        if (token.startsWith('test_')) {
          Paddle.Environment.set('sandbox');
        }

        Paddle.Initialize({
          token,
          eventCallback: function (event) {
            if (event.name === 'checkout.loaded') {
              setStatus('Checkout loaded', 'Paddle is ready. Continue in the payment form on this page.');
            }
            if (event.name === 'checkout.closed') {
              setStatus('Checkout closed', 'The checkout was closed before payment completed. You can return to Aliolo billing and try again.');
            }
            if (event.name === 'checkout.completed') {
              setStatus('Payment submitted', 'Your payment was submitted. Aliolo will unlock premium access after Paddle confirms the subscription.');
            }
            if (event.name === 'checkout.error') {
              fallbackEl.classList.add('visible');
              setStatus('Checkout error', 'Paddle reported an error while loading checkout. Return to billing and try again.', true);
            }
          },
          checkout: {
            settings: {
              displayMode: 'inline',
              frameTarget: 'checkout-container',
              frameInitialHeight: 540,
              frameStyle: 'width: 100%; min-width: 312px; background-color: transparent; border: none;',
              theme: 'light',
              variant: 'one-page',
              showAddTaxId: false,
              allowLogout: true,
            },
          },
        });

        setStatus('Opening checkout', 'Paddle is opening your secure payment form now.');
      } catch (error) {
        fallbackEl.classList.add('visible');
        setStatus(
          'Checkout failed to initialize',
          'Paddle.js could not initialize on this page. Verify the client-side token and retry from Aliolo billing.',
          true,
        );
      }
    })();
  </script>
</body>
</html>"""

LANDING_LAYOUT = """<!DOCTYPE html>
<html lang="{{LANG}}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{T_landing_meta_title}}</title>
  <meta name="description" content="{{T_landing_meta_desc}}">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
  <meta property="og:type" content="website">
  <meta property="og:title" content="{{T_landing_meta_title}}">
  <meta property="og:description" content="{{T_landing_meta_desc}}">
  <meta property="og:url" content="{{CANONICAL_URL}}">
  <meta property="og:image" content="https://aliolo.com/aliolo-social-preview.png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="Aliolo visual learning cards and spaced repetition preview">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{{T_landing_meta_title}}">
  <meta name="twitter:description" content="{{T_landing_meta_desc}}">
  <meta name="twitter:image" content="https://aliolo.com/aliolo-social-preview.png">
  <link rel="canonical" href="{{CANONICAL_URL}}">
  <link rel="apple-touch-icon" href="/icons/Icon-192.png">
  <link rel="icon" type="image/webp" href="/app_icon.webp">
  <link rel="manifest" href="/manifest.json">
{{SEO_ALTERNATES}}
  <script>
    (() => {
      const params = new URLSearchParams(window.location.search);
      if (params.has('type') || params.has('invite')) {
        window.location.replace('/login' + window.location.search + window.location.hash);
      }
    })();
  </script>
  <style>{{LANDING_STYLES}</style>
</head>
<body>
  <a class="skip-link" href="#main-content">Skip to content</a>
  <header>
    <div class="shell brand">
      <a class="brand-name" href="{{HOME_URL}}" aria-label="Aliolo home">
        <img src="/app_icon.webp" alt="Aliolo logo">
        aliolo
      </a>
      <nav aria-label="Site navigation">
        <a class="desktop-link" href="#features">{{T_landing_nav_features}}</a>
        <a class="desktop-link" href="#workflow">{{T_landing_nav_how_it_works}}</a>
        <a class="desktop-link" href="#pricing">{{T_landing_nav_pricing}}</a>
        {{LANG_SWITCHER}}
        <a href="{{LOGIN_URL}}?login=1" class="nav-login">{{T_landing_nav_login}}</a>
        <a href="{{PREFIX}}/login" class="nav-cta">{{T_landing_nav_cta}}</a>
      </nav>
    </div>
  </header>

  <main class="shell" id="main-content">
    <section class="hero">
      <div class="hero-copy">
        <div class="eyebrow">{{T_landing_hero_eyebrow}}</div>
        <h1>{{T_landing_hero_h1}}</h1>
        <p>{{T_landing_hero_p}}</p>
        <div class="cta-group">
          <a href="{{PREFIX}}/login" class="btn btn-primary">{{T_landing_hero_btn_primary}}</a>
          <a href="{{LOGIN_URL}}?login=1" class="btn btn-secondary">{{T_landing_hero_btn_secondary}}</a>
        </div>
        <div class="proof-row" aria-label="Product highlights">
          <div class="proof">
            <strong>{{T_landing_hero_proof_1_title}}</strong>
            <span>{{T_landing_hero_proof_1_desc}}</span>
          </div>
          <div class="proof">
            <strong>{{T_landing_hero_proof_2_title}}</strong>
            <span>{{T_landing_hero_proof_2_desc}}</span>
          </div>
          <div class="proof">
            <strong>{{T_landing_hero_proof_3_title}}</strong>
            <span>{{T_landing_hero_proof_3_desc}}</span>
          </div>
        </div>
      </div>
      <aside class="hero-panel" aria-label="Aliolo study workflow preview">
        <figure class="product-preview">
          <img src="/landing-product-preview.jpg" alt="Aliolo visual flashcard lesson showing an Akita Inu on a tablet" width="1200" height="675" fetchpriority="high">
          <figcaption class="preview-caption">
            <div>
              <strong>{{T_landing_hero_preview_title}}</strong>
              <span>{{T_landing_hero_preview_desc}}</span>
            </div>
            <div class="preview-chip">{{T_landing_hero_preview_chip}}</div>
          </figcaption>
        </figure>
      </aside>
    </section>

    <section class="section" id="features">
      <div class="section-heading">
        <h2>{{T_landing_features_h2}}</h2>
        <p>{{T_landing_features_p}}</p>
      </div>
      <div class="feature-grid">
        <article class="feature-card">
          <div class="feature-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="m5 18 5-5 3 3 2-2 4 4"/></svg></div>
          <h3>{{T_landing_feature_1_title}}</h3>
          <p>{{T_landing_feature_1_desc}}</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M20 12a8 8 0 1 1-2.34-5.66"/><path d="M20 4v6h-6"/><path d="M9.5 12.5 11 14l3.5-4"/></svg></div>
          <h3>{{T_landing_feature_2_title}}</h3>
          <p>{{T_landing_feature_2_desc}}</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M4 6.5 12 3l8 3.5-8 3.5z"/><path d="M6 9v6.5L12 19l6-3.5V9"/><path d="M20 7v6"/></svg></div>
          <h3>{{T_landing_feature_3_title}}</h3>
          <p>{{T_landing_feature_3_desc}}</p>
        </article>
      </div>
    </section>

    <section class="section" id="workflow">
      <div class="section-heading">
        <h2>{{T_landing_workflow_h2}}</h2>
        <p>{{T_landing_workflow_p}}</p>
      </div>
      <div class="steps">
        <article class="step">
          <strong>01</strong>
          <h3>{{T_landing_step_1_title}}</h3>
          <p>{{T_landing_step_1_desc}}</p>
        </article>
        <article class="step">
          <strong>02</strong>
          <h3>{{T_landing_step_2_title}}</h3>
          <p>{{T_landing_step_2_desc}}</p>
        </article>
        <article class="step">
          <strong>03</strong>
          <h3>{{T_landing_step_3_title}}</h3>
          <p>{{T_landing_step_3_desc}}</p>
        </article>
      </div>
    </section>

    <section class="section" id="pricing">
      <div class="section-heading">
        <h2>{{T_landing_pricing_h2}}</h2>
        <p>{{T_landing_pricing_p}}</p>
      </div>
      <div class="pricing-grid">
        <article class="price-card">
          <span class="price-tag">{{T_pricing}}</span>
          <h3>{{T_pricing}}</h3>
          <div class="price-amount">$2.99</div>
          <p>{{T_landing_plan_weekly_desc}}</p>
          <ul>
            <li>{{T_landing_plan_weekly_item_1}}</li>
            <li>{{T_landing_plan_weekly_item_2}}</li>
            <li>{{T_landing_plan_weekly_item_3}}</li>
          </ul>
          <a href="{{PREFIX}}/pricing" class="btn btn-secondary" aria-label="View weekly plan details">{{T_landing_plan_weekly_btn}}</a>
        </article>
        <article class="price-card featured">
          <span class="price-tag">{{T_pricing}}</span>
          <h3>{{T_pricing}}</h3>
          <div class="price-amount">$8.99</div>
          <p>{{T_landing_plan_monthly_desc}}</p>
          <ul>
            <li>{{T_landing_plan_monthly_item_1}}</li>
            <li>{{T_landing_plan_monthly_item_2}}</li>
            <li>{{T_landing_plan_monthly_item_3}}</li>
          </ul>
          <a href="{{PREFIX}}/pricing" class="btn btn-primary" aria-label="View monthly plan details">{{T_landing_plan_monthly_btn}}</a>
        </article>
        <article class="price-card">
          <span class="price-tag">{{T_pricing}}</span>
          <h3>{{T_pricing}}</h3>
          <div class="price-amount">$80.99</div>
          <p>{{T_landing_plan_yearly_desc}}</p>
          <ul>
            <li>{{T_landing_plan_yearly_item_1}}</li>
            <li>{{T_landing_plan_yearly_item_2}}</li>
            <li>{{T_landing_plan_yearly_item_3}}</li>
          </ul>
          <a href="{{PREFIX}}/pricing" class="btn btn-secondary" aria-label="View yearly plan details">{{T_landing_plan_yearly_btn}}</a>
        </article>
      </div>
    </section>

    <section class="section">
      <div class="trust-panel">
        <div class="trust-grid">
          <div>
            <h2>{{T_landing_trust_h2}}</h2>
            <p>{{T_landing_trust_p}}</p>
            <div class="trust-list">
              <div><strong>{{T_landing_trust_item_1_title}}</strong> {{T_landing_trust_item_1_desc}}</div>
              <div><strong>{{T_landing_trust_item_2_title}}</strong> {{T_landing_trust_item_2_desc}}</div>
              <div><strong>{{T_landing_trust_item_3_title}}</strong> {{T_landing_trust_item_3_desc}}</div>
            </div>
          </div>
          <div class="mini-faq" aria-label="Mini FAQ">
            <div>
              <strong>{{T_landing_faq_1_q}}</strong>
              {{T_landing_faq_1_a}}
            </div>
            <div>
              <strong>{{T_landing_faq_2_q}}</strong>
              {{T_landing_faq_2_a}}
            </div>
            <div>
              <strong>{{T_landing_faq_3_q}}</strong>
              {{T_landing_faq_3_a}}
            </div>
          </div>
        </div>
      </div>
      <div class="final-cta">
        <div>
          <h2>{{T_landing_final_h2}}</h2>
          <p>{{T_landing_final_p}}</p>
        </div>
        <a href="{{PREFIX}}/login" class="btn">{{T_landing_final_btn}}</a>
      </div>
    </section>
  </main>

  <footer>
    <div class="shell">
      <div class="footer-grid">
        <div class="footer-brand">
          <strong>Aliolo</strong>
          <p>{{T_landing_footer_desc}}</p>
        </div>
        <div class="footer-links">
          <a href="{{PREFIX}}/privacy">{{T_privacy}}</a>
          <a href="{{PREFIX}}/terms">{{T_terms}}</a>
          <a href="{{PREFIX}}/refund">{{T_refunds}}</a>
          <a href="{{PREFIX}}/pricing">{{T_pricing}}</a>
          <a href="mailto:vitalii@nohainc.com">{{T_support}}</a>
        </div>
      </div>
      <div class="legal-note">
        <strong>{{T_landing_footer_mor}}</strong> {{T_landing_footer_mor_desc}}
      </div>
    </div>
  </footer>
</body>
</html>"""

def parse_nano_map(content: str) -> dict:
    result = {}
    lines = content.splitlines()
    current_key = None
    current_value_lines = []
    in_multiline = False
    
    for line in lines:
        trimmed = line.strip()
        if not trimmed or trimmed.startswith('#'):
            if in_multiline:
                current_value_lines.append('')
            continue
            
        leading_spaces = len(line) - len(line.lstrip())
        
        if in_multiline:
            if leading_spaces >= 8:
                current_value_lines.append(line[8:])
                continue
            else:
                result[current_key] = "\n".join(current_value_lines)
                in_multiline = False
                current_key = None
                current_value_lines = []
                
        if trimmed == '..':
            continue
            
        if leading_spaces == 4:
            if trimmed.endswith('|'):
                current_key = trimmed[:-1].strip()
                in_multiline = True
                current_value_lines = []
            else:
                first_space = trimmed.find(' ')
                if first_space != -1:
                    key = trimmed[:first_space].strip()
                    val = trimmed[first_space+1:].strip()
                    if val.startswith('"') and val.endswith('"'):
                        val = json.loads(val)
                    result[key] = val
                else:
                    result[trimmed] = ""
                    
    if in_multiline and current_key:
        result[current_key] = "\n".join(current_value_lines)
        
    return result

def render_legal(lang: str, t: dict, active: str, page_path: str, body_content: str, updated_date: str, structured_data = None) -> str:
    nav_list = [
        ('home', 'Home', '/'),
        ('privacy', 'Privacy', '/privacy'),
        ('terms', 'Terms', '/terms'),
        ('refund', 'Refunds', '/refund'),
        ('pricing', 'Pricing', '/pricing'),
    ]
    
    prefix = "" if lang == "en" else f"/{lang}"
    home_url = "/" if lang == "en" else f"/{lang}"
    
    seo_alternate_links = []
    for l in SUPPORTED_LANGUAGES:
        seo_alternate_links.append(f'  <link rel="alternate" hreflang="{l}" href="https://aliolo.com{"" if l == "en" else "/" + l}{page_path}">')
    seo_alternates_html = "\n".join(seo_alternate_links)
    
    legal_info_label = t.get('legal_info', 'Legal information')
    last_updated_label = t.get('last_updated', 'Last updated')
    support_label = t.get('support', 'Support')
    
    nav_html = []
    for key, label_default, href in nav_list:
        label = t.get(key, label_default)
        active_class = "active" if active == key else ""
        link_href = home_url if (key == 'home') else f"{prefix}{href}"
        nav_html.append(f'<a class="{active_class}" href="{link_href}">{label}</a>')
    nav_links_html = "\n        ".join(nav_html)
    
    title = t.get(f"{active}_title", "Aliolo legal")
    subtitle = t.get(f"{active}_subtitle", "")

    if structured_data is None:
        structured_data = {
            '@context': 'https://schema.org',
            '@type': 'WebPage',
            'name': title,
            'description': subtitle,
            'url': f'https://aliolo.com{prefix}{page_path}',
            'dateModified': updated_date,
            'isPartOf': {
                '@type': 'WebSite',
                'name': 'Aliolo',
                'url': 'https://aliolo.com',
            },
        }
    structured_data_html = f'<script type="application/ld+json">{json.dumps(structured_data, ensure_ascii=False)}</script>'

    html = LEGAL_LAYOUT
    html = html.replace("{{LANG}}", lang)
    html = html.replace("{{PREFIX}}", prefix)
    html = html.replace("{{HOME_URL}}", home_url)
    html = html.replace("{{PAGE_PATH}}", page_path)
    html = html.replace("{{TITLE}}", title)
    html = html.replace("{{SUBTITLE}}", subtitle)
    html = html.replace("{{SEO_ALTERNATES}}", seo_alternates_html)
    html = html.replace("{{STRUCTURED_DATA_HTML}}", structured_data_html)
    html = html.replace("{{NAV_LINKS}}", nav_links_html)
    html = html.replace("{{LEGAL_INFO_LABEL}}", legal_info_label)
    html = html.replace("{{LAST_UPDATED_LABEL}}", last_updated_label)
    html = html.replace("{{UPDATED_DATE}}", updated_date)
    html = html.replace("{{SUPPORT_LABEL}}", support_label)
    html = html.replace("{{BODY_CONTENT}}", body_content)
    html = html.replace("{{LANG_SWITCHER}}", render_lang_switcher(lang, active))
    html = html.replace("{{LEGAL_STYLES}", LEGAL_STYLES)
    return html

def render_pay(lang: str, t: dict) -> str:
    prefix = "" if lang == "en" else f"/{lang}"
    home_url = "/" if lang == "en" else f"/{lang}"
    
    checkout_title = t.get("checkout_title", "Aliolo Checkout")
    checkout_subtitle = t.get("checkout_subtitle", "Secure checkout for Aliolo Premium subscriptions.")
    checkout_eyebrow = t.get("checkout_eyebrow", "Secure checkout")
    checkout_h1 = t.get("checkout_h1", "Complete your Aliolo Premium purchase.")
    
    checkout_status_title = t.get("checkout_status_title", "Waiting for checkout")
    checkout_status_desc = t.get("checkout_status_desc", "If you opened this page from Aliolo billing, the payment form should appear automatically.")
    
    payment_support_title = t.get("checkout_payment_support_title", "Payment support")
    payment_support_desc = t.get("checkout_payment_support_desc", "Web payments are processed by Paddle.com as Merchant of Record.")
    
    billing_title = t.get("checkout_billing_title", "Subscription billing")
    billing_desc = t.get("checkout_billing_desc", "Aliolo Premium renews automatically until canceled. You can cancel later through Paddle or your Aliolo account.")
    
    policy_title = t.get("checkout_policy_title", "Need policy details?")
    policy_desc = t.get("checkout_policy_desc", "Review pricing, subscription terms, privacy, and refund information before completing your purchase.")

    html = PAY_LAYOUT
    html = html.replace("{{LANG}}", lang)
    html = html.replace("{{PREFIX}}", prefix)
    html = html.replace("{{HOME_URL}}", home_url)
    html = html.replace("{{CHECKOUT_TITLE}}", checkout_title)
    html = html.replace("{{CHECKOUT_SUBTITLE}}", checkout_subtitle)
    html = html.replace("{{CHECKOUT_EYEBROW}}", checkout_eyebrow)
    html = html.replace("{{CHECKOUT_H1}}", checkout_h1)
    html = html.replace("{{CHECKOUT_STATUS_TITLE}}", checkout_status_title)
    html = html.replace("{{CHECKOUT_STATUS_DESC}}", checkout_status_desc)
    html = html.replace("{{PAYMENT_SUPPORT_TITLE}}", payment_support_title)
    html = html.replace("{{PAYMENT_SUPPORT_DESC}}", payment_support_desc)
    html = html.replace("{{BILLING_TITLE}}", billing_title)
    html = html.replace("{{BILLING_DESC}}", billing_desc)
    html = html.replace("{{POLICY_TITLE}}", policy_title)
    html = html.replace("{{POLICY_DESC}}", policy_desc)
    html = html.replace("{{PRICING_LABEL}}", t.get('pricing', 'Pricing'))
    html = html.replace("{{TERMS_LABEL}}", t.get('terms', 'Terms'))
    html = html.replace("{{PRIVACY_LABEL}}", t.get('privacy', 'Privacy'))
    html = html.replace("{{REFUND_LABEL}}", t.get('refunds', 'Refund'))
    html = html.replace("{{LANG_SWITCHER}}", render_lang_switcher(lang, "pay"))
    html = html.replace("{{PAY_STYLES}", PAY_STYLES)
    return html

def render_landing(lang: str, t: dict) -> str:
    prefix = "" if lang == "en" else f"/{lang}"
    home_url = "/" if lang == "en" else f"/{lang}"
    login_url = "/login" if lang == "en" else f"/{lang}/login"
    
    canonical_url = "https://aliolo.com/" if lang == "en" else f"https://aliolo.com/{lang}"
    
    seo_alternate_links = []
    for l in SUPPORTED_LANGUAGES:
        alt_url = "https://aliolo.com/" if l == "en" else f"https://aliolo.com/{l}"
        seo_alternate_links.append(f'  <link rel="alternate" hreflang="{l}" href="{alt_url}">')
    seo_alternates_html = "\n  ".join(seo_alternate_links)

    html = LANDING_LAYOUT
    html = html.replace("{{LANG}}", lang)
    html = html.replace("{{PREFIX}}", prefix)
    html = html.replace("{{HOME_URL}}", home_url)
    html = html.replace("{{LOGIN_URL}}", login_url)
    html = html.replace("{{CANONICAL_URL}}", canonical_url)
    html = html.replace("{{SEO_ALTERNATES}}", seo_alternates_html)
    html = html.replace("{{LANG_SWITCHER}}", render_lang_switcher(lang, "landing"))
    html = html.replace("{{LANDING_STYLES}", LANDING_STYLES)
    
    # Replace all translations keys dynamically
    for key, val in t.items():
        html = html.replace(f"{{{{T_{key}}}}}", val)
        
    return html

def main():
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent.parent
    
    # Static pages output directory
    web_dir = project_root / "web"
    web_dir.mkdir(parents=True, exist_ok=True)
    
    translations_dir = project_root / "assets" / "translations" / "web"
    
    # Updates legal date mod
    updated_date = "April 28, 2026"
    
    for lang in SUPPORTED_LANGUAGES:
        print(f"Generating static HTML pages for language: {lang}...")
        
        # Load translation nano file
        nano_file = translations_dir / f"{lang}.nano"
        if not nano_file.exists():
            print(f"  Warning: Translation file {nano_file} not found. Skipping {lang}.")
            continue
            
        t = parse_nano_map(nano_file.read_text(encoding="utf-8"))
        
        # Determine output directory for this language
        out_dir = web_dir if lang == "en" else web_dir / lang
        out_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate legal pages
        privacy_html = render_legal(lang, t, "privacy", "/privacy", t.get("privacy_body", ""), updated_date)
        terms_html = render_legal(lang, t, "terms", "/terms", t.get("terms_body", ""), updated_date)
        refund_html = render_legal(lang, t, "refund", "/refund", t.get("refund_body", ""), updated_date)
        
        # Pricing page structured data
        prefix = "" if lang == "en" else f"/{lang}"
        pricing_structured_data = [
            {
                '@context': 'https://schema.org',
                '@type': 'WebPage',
                'name': t.get('pricing_title', 'Aliolo Premium Pricing'),
                'description': t.get('pricing_subtitle', 'Simple subscription options for unlocking the full Aliolo visual learning experience.'),
                'url': f'https://aliolo.com{prefix}/pricing',
                'isPartOf': {
                    '@type': 'WebSite',
                    'name': 'Aliolo',
                    'url': 'https://aliolo.com',
                },
            },
            {
                '@context': 'https://schema.org',
                '@type': 'SoftwareApplication',
                'name': 'Aliolo',
                'applicationCategory': 'EducationalApplication',
                'operatingSystem': 'Web, Android, iOS',
                'url': 'https://aliolo.com',
                'offers': [
                    {
                        '@type': 'Offer',
                        'name': 'Weekly',
                        'price': '2.99',
                        'priceCurrency': 'USD',
                    },
                    {
                        '@type': 'Offer',
                        'name': 'Monthly',
                        'price': '8.99',
                        'priceCurrency': 'USD',
                    },
                    {
                        '@type': 'Offer',
                        'name': 'Yearly',
                        'price': '80.99',
                        'priceCurrency': 'USD',
                    },
                ],
            },
        ]
        
        pricing_html = render_legal(
            lang, t, "pricing", "/pricing", t.get("pricing_body", ""), updated_date, pricing_structured_data
        )
        
        # Generate checkout page
        pay_html = render_pay(lang, t)
        
        # Generate landing page
        landing_html = render_landing(lang, t)
        
        # Write files
        (out_dir / "privacy.html").write_text(privacy_html, encoding="utf-8")
        (out_dir / "terms.html").write_text(terms_html, encoding="utf-8")
        (out_dir / "refund.html").write_text(refund_html, encoding="utf-8")
        (out_dir / "pricing.html").write_text(pricing_html, encoding="utf-8")
        (out_dir / "pay.html").write_text(pay_html, encoding="utf-8")
        (out_dir / "landing.html").write_text(landing_html, encoding="utf-8")
        
        print(f"  Generated 6 HTML files under: {out_dir}")

if __name__ == "__main__":
    main()
