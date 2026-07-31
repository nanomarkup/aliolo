#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import html.parser
import json
import os
import re
import shutil
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path

SUBJECT_ID = "35b2f5c1-10be-4c1d-b915-1159ef35fe26"
SUBJECT_NAME = "Flags of the World"
DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SCRIPT_DIR = Path(__file__).resolve().parent
TMP_DIR = SCRIPT_DIR / ".tmp"
WRANGLER_BIN = Path("api/node_modules/wrangler/bin/wrangler.js")
WRANGLER_LOG_DIR = Path.home() / ".config" / ".wrangler" / "logs"
GLOBAL_OBJECT_PATTERN = re.compile(
    r"cards/(?P<card_id>[0-9a-f-]+)/global_(?P<ts>\d+)\.(?P<ext>[A-Za-z0-9]+)"
)

HTML_SOURCE = """
<div class="tiles">
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-china/" title="Flag of China"><img alt="Flag of China" srcset="https://cdn.countryflags.com/thumbs/china/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/china/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/china/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of China</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-india/" title="Flag of India"><img alt="Flag of India" srcset="https://cdn.countryflags.com/thumbs/india/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/india/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/india/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of India</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-europe/" title="Flag of Europe"><img alt="Flag of Europe" srcset="https://cdn.countryflags.com/thumbs/europe/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/europe/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/europe/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Europe</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-arab-league/" title="Flag of the Arab League"><img alt="Flag of the Arab League" srcset="https://cdn.countryflags.com/thumbs/arab-league/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/arab-league/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/arab-league/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of the Arab League</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-united-states-the/" title="Flag of United States, the"><img alt="Flag of United States, the" srcset="https://cdn.countryflags.com/thumbs/united-states-of-america/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/united-states-of-america/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/united-states-of-america/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of United States, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-indonesia/" title="Flag of Indonesia"><img alt="Flag of Indonesia" srcset="https://cdn.countryflags.com/thumbs/indonesia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/indonesia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/indonesia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Indonesia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-brazil/" title="Flag of Brazil"><img alt="Flag of Brazil" srcset="https://cdn.countryflags.com/thumbs/brazil/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/brazil/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/brazil/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Brazil</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-pakistan/" title="Flag of Pakistan"><img alt="Flag of Pakistan" srcset="https://cdn.countryflags.com/thumbs/pakistan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/pakistan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/pakistan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Pakistan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-nigeria/" title="Flag of Nigeria"><img alt="Flag of Nigeria" srcset="https://cdn.countryflags.com/thumbs/nigeria/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/nigeria/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/nigeria/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Nigeria</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bangladesh/" title="Flag of Bangladesh"><img alt="Flag of Bangladesh" srcset="https://cdn.countryflags.com/thumbs/bangladesh/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bangladesh/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bangladesh/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bangladesh</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-russia/" title="Flag of Russia"><img alt="Flag of Russia" srcset="https://cdn.countryflags.com/thumbs/russia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/russia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/russia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Russia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-japan/" title="Flag of Japan"><img alt="Flag of Japan" srcset="https://cdn.countryflags.com/thumbs/japan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/japan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/japan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Japan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-mexico/" title="Flag of Mexico"><img alt="Flag of Mexico" srcset="https://cdn.countryflags.com/thumbs/mexico/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/mexico/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/mexico/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Mexico</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-ethiopia/" title="Flag of Ethiopia"><img alt="Flag of Ethiopia" srcset="https://cdn.countryflags.com/thumbs/ethiopia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/ethiopia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/ethiopia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Ethiopia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-philippines-the/" title="Flag of Philippines, the"><img alt="Flag of Philippines, the" srcset="https://cdn.countryflags.com/thumbs/philippines/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/philippines/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/philippines/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Philippines, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-egypt/" title="Flag of Egypt"><img alt="Flag of Egypt" srcset="https://cdn.countryflags.com/thumbs/egypt/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/egypt/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/egypt/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Egypt</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-vietnam/" title="Flag of Vietnam"><img alt="Flag of Vietnam" srcset="https://cdn.countryflags.com/thumbs/vietnam/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/vietnam/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/vietnam/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Vietnam</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-congo-democratic-republic-of-the/" title="Flag of Congo, Democratic Republic of the"><img alt="Flag of Congo, Democratic Republic of the" srcset="https://cdn.countryflags.com/thumbs/congo-democratic-republic-of-the/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/congo-democratic-republic-of-the/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/congo-democratic-republic-of-the/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Congo, Democratic Republic of the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-iran/" title="Flag of Iran"><img alt="Flag of Iran" srcset="https://cdn.countryflags.com/thumbs/iran/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/iran/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/iran/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Iran</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-turkey/" title="Flag of Turkey"><img alt="Flag of Turkey" srcset="https://cdn.countryflags.com/thumbs/turkey/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/turkey/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/turkey/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Turkey</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-germany/" title="Flag of Germany"><img alt="Flag of Germany" srcset="https://cdn.countryflags.com/thumbs/germany/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/germany/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/germany/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Germany</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-thailand/" title="Flag of Thailand"><img alt="Flag of Thailand" srcset="https://cdn.countryflags.com/thumbs/thailand/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/thailand/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/thailand/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Thailand</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-united-kingdom-the/" title="Flag of United Kingdom, the"><img alt="Flag of United Kingdom, the" srcset="https://cdn.countryflags.com/thumbs/united-kingdom/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/united-kingdom/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/united-kingdom/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of United Kingdom, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-france/" title="Flag of France"><img alt="Flag of France" srcset="https://cdn.countryflags.com/thumbs/france/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/france/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/france/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of France</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-italy/" title="Flag of Italy"><img alt="Flag of Italy" srcset="https://cdn.countryflags.com/thumbs/italy/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/italy/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/italy/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Italy</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-myanmar/" title="Flag of Myanmar"><img alt="Flag of Myanmar" srcset="https://cdn.countryflags.com/thumbs/myanmar/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/myanmar/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/myanmar/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Myanmar</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-england/" title="Flag of England"><img alt="Flag of England" srcset="https://cdn.countryflags.com/thumbs/england/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/england/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/england/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of England</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-south-africa/" title="Flag of South Africa"><img alt="Flag of South Africa" srcset="https://cdn.countryflags.com/thumbs/south-africa/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/south-africa/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/south-africa/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of South Africa</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-tanzania/" title="Flag of Tanzania"><img alt="Flag of Tanzania" srcset="https://cdn.countryflags.com/thumbs/tanzania/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/tanzania/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/tanzania/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Tanzania</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-korea-south/" title="Flag of Korea, South"><img alt="Flag of Korea, South" srcset="https://cdn.countryflags.com/thumbs/south-korea/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/south-korea/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/south-korea/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Korea, South</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-spain/" title="Flag of Spain"><img alt="Flag of Spain" srcset="https://cdn.countryflags.com/thumbs/spain/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/spain/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/spain/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Spain</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-colombia/" title="Flag of Colombia"><img alt="Flag of Colombia" srcset="https://cdn.countryflags.com/thumbs/colombia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/colombia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/colombia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Colombia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-kenya/" title="Flag of Kenya"><img alt="Flag of Kenya" srcset="https://cdn.countryflags.com/thumbs/kenya/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/kenya/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/kenya/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Kenya</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-argentina/" title="Flag of Argentina"><img alt="Flag of Argentina" srcset="https://cdn.countryflags.com/thumbs/argentina/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/argentina/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/argentina/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Argentina</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-ukraine/" title="Flag of Ukraine"><img alt="Flag of Ukraine" srcset="https://cdn.countryflags.com/thumbs/ukraine/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/ukraine/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/ukraine/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Ukraine</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-algeria/" title="Flag of Algeria"><img alt="Flag of Algeria" srcset="https://cdn.countryflags.com/thumbs/algeria/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/algeria/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/algeria/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Algeria</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-uganda/" title="Flag of Uganda"><img alt="Flag of Uganda" srcset="https://cdn.countryflags.com/thumbs/uganda/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/uganda/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/uganda/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Uganda</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-iraq/" title="Flag of Iraq"><img alt="Flag of Iraq" srcset="https://cdn.countryflags.com/thumbs/iraq/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/iraq/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/iraq/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Iraq</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-poland/" title="Flag of Poland"><img alt="Flag of Poland" srcset="https://cdn.countryflags.com/thumbs/poland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/poland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/poland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Poland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-sudan/" title="Flag of Sudan"><img alt="Flag of Sudan" srcset="https://cdn.countryflags.com/thumbs/sudan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/sudan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/sudan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Sudan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-canada/" title="Flag of Canada"><img alt="Flag of Canada" srcset="https://cdn.countryflags.com/thumbs/canada/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/canada/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/canada/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Canada</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-afghanistan/" title="Flag of Afghanistan"><img alt="Flag of Afghanistan" srcset="https://cdn.countryflags.com/thumbs/afghanistan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/afghanistan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/afghanistan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Afghanistan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-morocco/" title="Flag of Morocco"><img alt="Flag of Morocco" srcset="https://cdn.countryflags.com/thumbs/morocco/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/morocco/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/morocco/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Morocco</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-malaysia/" title="Flag of Malaysia"><img alt="Flag of Malaysia" srcset="https://cdn.countryflags.com/thumbs/malaysia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/malaysia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/malaysia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Malaysia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-venezuela/" title="Flag of Venezuela"><img alt="Flag of Venezuela" srcset="https://cdn.countryflags.com/thumbs/venezuela/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/venezuela/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/venezuela/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Venezuela</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-peru/" title="Flag of Peru"><img alt="Flag of Peru" srcset="https://cdn.countryflags.com/thumbs/peru/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/peru/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/peru/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Peru</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-uzbekistan/" title="Flag of Uzbekistan"><img alt="Flag of Uzbekistan" srcset="https://cdn.countryflags.com/thumbs/uzbekistan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/uzbekistan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/uzbekistan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Uzbekistan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-nepal/" title="Flag of Nepal"><img alt="Flag of Nepal" srcset="https://cdn.countryflags.com/thumbs/nepal/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/nepal/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/nepal/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Nepal</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-angola/" title="Flag of Angola"><img alt="Flag of Angola" srcset="https://cdn.countryflags.com/thumbs/angola/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/angola/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/angola/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Angola</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-saudi-arabia/" title="Flag of Saudi Arabia"><img alt="Flag of Saudi Arabia" srcset="https://cdn.countryflags.com/thumbs/saudi-arabia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/saudi-arabia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/saudi-arabia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Saudi Arabia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-yemen/" title="Flag of Yemen"><img alt="Flag of Yemen" srcset="https://cdn.countryflags.com/thumbs/yemen/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/yemen/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/yemen/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Yemen</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-ghana/" title="Flag of Ghana"><img alt="Flag of Ghana" srcset="https://cdn.countryflags.com/thumbs/ghana/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/ghana/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/ghana/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Ghana</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-mozambique/" title="Flag of Mozambique"><img alt="Flag of Mozambique" srcset="https://cdn.countryflags.com/thumbs/mozambique/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/mozambique/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/mozambique/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Mozambique</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-korea-north/" title="Flag of Korea, North"><img alt="Flag of Korea, North" srcset="https://cdn.countryflags.com/thumbs/north-korea/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/north-korea/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/north-korea/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Korea, North</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-madagascar/" title="Flag of Madagascar"><img alt="Flag of Madagascar" srcset="https://cdn.countryflags.com/thumbs/madagascar/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/madagascar/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/madagascar/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Madagascar</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-cameroon/" title="Flag of Cameroon"><img alt="Flag of Cameroon" srcset="https://cdn.countryflags.com/thumbs/cameroon/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/cameroon/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/cameroon/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Cameroon</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-cote-d-ivoire/" title="Flag of Côte d’ Ivoire"><img alt="Flag of Côte d’ Ivoire" srcset="https://cdn.countryflags.com/thumbs/cote-d-ivoire/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/cote-d-ivoire/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/cote-d-ivoire/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Côte d’ Ivoire</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-taiwan/" title="Flag of Taiwan"><img alt="Flag of Taiwan" srcset="https://cdn.countryflags.com/thumbs/taiwan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/taiwan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/taiwan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Taiwan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-australia/" title="Flag of Australia"><img alt="Flag of Australia" srcset="https://cdn.countryflags.com/thumbs/australia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/australia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/australia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Australia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-sri-lanka/" title="Flag of Sri Lanka"><img alt="Flag of Sri Lanka" srcset="https://cdn.countryflags.com/thumbs/sri-lanka/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/sri-lanka/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/sri-lanka/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Sri Lanka</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-romania/" title="Flag of Romania"><img alt="Flag of Romania" srcset="https://cdn.countryflags.com/thumbs/romania/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/romania/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/romania/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Romania</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-burkina-faso/" title="Flag of Burkina Faso"><img alt="Flag of Burkina Faso" srcset="https://cdn.countryflags.com/thumbs/burkina-faso/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/burkina-faso/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/burkina-faso/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Burkina Faso</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-syria/" title="Flag of Syria"><img alt="Flag of Syria" srcset="https://cdn.countryflags.com/thumbs/syria/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/syria/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/syria/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Syria</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-niger/" title="Flag of Niger"><img alt="Flag of Niger" srcset="https://cdn.countryflags.com/thumbs/niger/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/niger/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/niger/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Niger</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-malawi/" title="Flag of Malawi"><img alt="Flag of Malawi" srcset="https://cdn.countryflags.com/thumbs/malawi/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/malawi/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/malawi/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Malawi</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-kazakhstan/" title="Flag of Kazakhstan"><img alt="Flag of Kazakhstan" srcset="https://cdn.countryflags.com/thumbs/kazakhstan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/kazakhstan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/kazakhstan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Kazakhstan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-mali/" title="Flag of Mali"><img alt="Flag of Mali" srcset="https://cdn.countryflags.com/thumbs/mali/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/mali/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/mali/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Mali</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-chile/" title="Flag of Chile"><img alt="Flag of Chile" srcset="https://cdn.countryflags.com/thumbs/chile/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/chile/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/chile/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Chile</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-netherlands-the/" title="Flag of Netherlands, the"><img alt="Flag of Netherlands, the" srcset="https://cdn.countryflags.com/thumbs/netherlands/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/netherlands/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/netherlands/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Netherlands, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-ecuador/" title="Flag of Ecuador"><img alt="Flag of Ecuador" srcset="https://cdn.countryflags.com/thumbs/ecuador/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/ecuador/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/ecuador/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Ecuador</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-cambodia/" title="Flag of Cambodia"><img alt="Flag of Cambodia" srcset="https://cdn.countryflags.com/thumbs/cambodia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/cambodia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/cambodia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Cambodia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-zambia/" title="Flag of Zambia"><img alt="Flag of Zambia" srcset="https://cdn.countryflags.com/thumbs/zambia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/zambia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/zambia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Zambia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-guatemala/" title="Flag of Guatemala"><img alt="Flag of Guatemala" srcset="https://cdn.countryflags.com/thumbs/guatemala/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/guatemala/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/guatemala/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Guatemala</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-senegal/" title="Flag of Senegal"><img alt="Flag of Senegal" srcset="https://cdn.countryflags.com/thumbs/senegal/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/senegal/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/senegal/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Senegal</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-zimbabwe/" title="Flag of Zimbabwe"><img alt="Flag of Zimbabwe" srcset="https://cdn.countryflags.com/thumbs/zimbabwe/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/zimbabwe/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/zimbabwe/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Zimbabwe</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-south-sudan/" title="Flag of South Sudan"><img alt="Flag of South Sudan" srcset="https://cdn.countryflags.com/thumbs/south-sudan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/south-sudan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/south-sudan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of South Sudan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-guinea/" title="Flag of Guinea"><img alt="Flag of Guinea" srcset="https://cdn.countryflags.com/thumbs/guinea/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/guinea/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/guinea/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Guinea</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-chad/" title="Flag of Chad"><img alt="Flag of Chad" srcset="https://cdn.countryflags.com/thumbs/chad/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/chad/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/chad/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Chad</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-rwanda/" title="Flag of Rwanda"><img alt="Flag of Rwanda" srcset="https://cdn.countryflags.com/thumbs/rwanda/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/rwanda/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/rwanda/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Rwanda</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-belgium/" title="Flag of Belgium"><img alt="Flag of Belgium" srcset="https://cdn.countryflags.com/thumbs/belgium/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/belgium/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/belgium/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Belgium</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-burundi/" title="Flag of Burundi"><img alt="Flag of Burundi" srcset="https://cdn.countryflags.com/thumbs/burundi/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/burundi/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/burundi/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Burundi</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-tunisia/" title="Flag of Tunisia"><img alt="Flag of Tunisia" srcset="https://cdn.countryflags.com/thumbs/tunisia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/tunisia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/tunisia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Tunisia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-cuba/" title="Flag of Cuba"><img alt="Flag of Cuba" srcset="https://cdn.countryflags.com/thumbs/cuba/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/cuba/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/cuba/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Cuba</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bolivia/" title="Flag of Bolivia"><img alt="Flag of Bolivia" srcset="https://cdn.countryflags.com/thumbs/bolivia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bolivia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bolivia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bolivia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-benin/" title="Flag of Benin"><img alt="Flag of Benin" srcset="https://cdn.countryflags.com/thumbs/benin/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/benin/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/benin/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Benin</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-somalia/" title="Flag of Somalia"><img alt="Flag of Somalia" srcset="https://cdn.countryflags.com/thumbs/somalia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/somalia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/somalia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Somalia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-portugal/" title="Flag of Portugal"><img alt="Flag of Portugal" srcset="https://cdn.countryflags.com/thumbs/portugal/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/portugal/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/portugal/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Portugal</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-greece/" title="Flag of Greece"><img alt="Flag of Greece" srcset="https://cdn.countryflags.com/thumbs/greece/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/greece/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/greece/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Greece</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-dominican-republic-the/" title="Flag of Dominican Republic, the"><img alt="Flag of Dominican Republic, the" srcset="https://cdn.countryflags.com/thumbs/dominican-republic/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/dominican-republic/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/dominican-republic/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Dominican Republic, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-czech-republic-the/" title="Flag of Czech Republic, the"><img alt="Flag of Czech Republic, the" srcset="https://cdn.countryflags.com/thumbs/czech-republic/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/czech-republic/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/czech-republic/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Czech Republic, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-haiti/" title="Flag of Haiti"><img alt="Flag of Haiti" srcset="https://cdn.countryflags.com/thumbs/haiti/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/haiti/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/haiti/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Haiti</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-jordan/" title="Flag of Jordan"><img alt="Flag of Jordan" srcset="https://cdn.countryflags.com/thumbs/jordan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/jordan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/jordan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Jordan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-azerbaijan/" title="Flag of Azerbaijan"><img alt="Flag of Azerbaijan" srcset="https://cdn.countryflags.com/thumbs/azerbaijan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/azerbaijan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/azerbaijan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Azerbaijan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-sweden/" title="Flag of Sweden"><img alt="Flag of Sweden" srcset="https://cdn.countryflags.com/thumbs/sweden/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/sweden/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/sweden/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Sweden</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-hungary/" title="Flag of Hungary"><img alt="Flag of Hungary" srcset="https://cdn.countryflags.com/thumbs/hungary/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/hungary/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/hungary/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Hungary</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-belarus/" title="Flag of Belarus"><img alt="Flag of Belarus" srcset="https://cdn.countryflags.com/thumbs/belarus/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/belarus/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/belarus/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Belarus</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-israel/" title="Flag of Israel"><img alt="Flag of Israel" srcset="https://cdn.countryflags.com/thumbs/israel/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/israel/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/israel/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Israel</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-honduras/" title="Flag of Honduras"><img alt="Flag of Honduras" srcset="https://cdn.countryflags.com/thumbs/honduras/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/honduras/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/honduras/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Honduras</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-austria/" title="Flag of Austria"><img alt="Flag of Austria" srcset="https://cdn.countryflags.com/thumbs/austria/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/austria/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/austria/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Austria</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-tajikistan/" title="Flag of Tajikistan"><img alt="Flag of Tajikistan" srcset="https://cdn.countryflags.com/thumbs/tajikistan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/tajikistan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/tajikistan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Tajikistan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-switzerland/" title="Flag of Switzerland"><img alt="Flag of Switzerland" srcset="https://cdn.countryflags.com/thumbs/switzerland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/switzerland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/switzerland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Switzerland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-togo/" title="Flag of Togo"><img alt="Flag of Togo" srcset="https://cdn.countryflags.com/thumbs/togo/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/togo/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/togo/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Togo</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-hong-kong/" title="Flag of Hong Kong"><img alt="Flag of Hong Kong" srcset="https://cdn.countryflags.com/thumbs/hongkong/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/hongkong/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/hongkong/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Hong Kong</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-laos/" title="Flag of Laos"><img alt="Flag of Laos" srcset="https://cdn.countryflags.com/thumbs/laos/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/laos/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/laos/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Laos</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-serbia/" title="Flag of Serbia"><img alt="Flag of Serbia" srcset="https://cdn.countryflags.com/thumbs/serbia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/serbia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/serbia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Serbia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bulgaria/" title="Flag of Bulgaria"><img alt="Flag of Bulgaria" srcset="https://cdn.countryflags.com/thumbs/bulgaria/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bulgaria/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bulgaria/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bulgaria</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-paraguay/" title="Flag of Paraguay"><img alt="Flag of Paraguay" srcset="https://cdn.countryflags.com/thumbs/paraguay/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/paraguay/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/paraguay/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Paraguay</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-papua-new-guinea/" title="Flag of Papua New Guinea"><img alt="Flag of Papua New Guinea" srcset="https://cdn.countryflags.com/thumbs/papua-new-guinea/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/papua-new-guinea/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/papua-new-guinea/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Papua New Guinea</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-libya/" title="Flag of Libya"><img alt="Flag of Libya" srcset="https://cdn.countryflags.com/thumbs/libya/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/libya/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/libya/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Libya</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-lebanon/" title="Flag of Lebanon"><img alt="Flag of Lebanon" srcset="https://cdn.countryflags.com/thumbs/lebanon/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/lebanon/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/lebanon/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Lebanon</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-el-salvador/" title="Flag of El Salvador"><img alt="Flag of El Salvador" srcset="https://cdn.countryflags.com/thumbs/el-salvador/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/el-salvador/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/el-salvador/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of El Salvador</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-sierra-leone/" title="Flag of Sierra Leone"><img alt="Flag of Sierra Leone" srcset="https://cdn.countryflags.com/thumbs/sierra-leone/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/sierra-leone/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/sierra-leone/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Sierra Leone</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-united-arab-emirates-the/" title="Flag of United Arab Emirates, the"><img alt="Flag of United Arab Emirates, the" srcset="https://cdn.countryflags.com/thumbs/united-arab-emirates/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/united-arab-emirates/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/united-arab-emirates/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of United Arab Emirates, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-nicaragua/" title="Flag of Nicaragua"><img alt="Flag of Nicaragua" srcset="https://cdn.countryflags.com/thumbs/nicaragua/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/nicaragua/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/nicaragua/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Nicaragua</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-eritrea/" title="Flag of Eritrea"><img alt="Flag of Eritrea" srcset="https://cdn.countryflags.com/thumbs/eritrea/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/eritrea/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/eritrea/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Eritrea</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-singapore/" title="Flag of Singapore"><img alt="Flag of Singapore" srcset="https://cdn.countryflags.com/thumbs/singapore/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/singapore/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/singapore/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Singapore</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-kyrgyzstan/" title="Flag of Kyrgyzstan"><img alt="Flag of Kyrgyzstan" srcset="https://cdn.countryflags.com/thumbs/kyrgyzstan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/kyrgyzstan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/kyrgyzstan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Kyrgyzstan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-central-african-republic-the/" title="Flag of Central-African Republic, the"><img alt="Flag of Central-African Republic, the" srcset="https://cdn.countryflags.com/thumbs/central-african-republic/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/central-african-republic/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/central-african-republic/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Central-African Republic, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-denmark/" title="Flag of Denmark"><img alt="Flag of Denmark" srcset="https://cdn.countryflags.com/thumbs/denmark/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/denmark/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/denmark/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Denmark</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-finland/" title="Flag of Finland"><img alt="Flag of Finland" srcset="https://cdn.countryflags.com/thumbs/finland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/finland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/finland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Finland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-slovakia/" title="Flag of Slovakia"><img alt="Flag of Slovakia" srcset="https://cdn.countryflags.com/thumbs/slovakia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/slovakia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/slovakia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Slovakia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-turkmenistan/" title="Flag of Turkmenistan"><img alt="Flag of Turkmenistan" srcset="https://cdn.countryflags.com/thumbs/turkmenistan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/turkmenistan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/turkmenistan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Turkmenistan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-norway/" title="Flag of Norway"><img alt="Flag of Norway" srcset="https://cdn.countryflags.com/thumbs/norway/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/norway/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/norway/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Norway</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-scotland/" title="Flag of Scotland"><img alt="Flag of Scotland" srcset="https://cdn.countryflags.com/thumbs/scotland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/scotland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/scotland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Scotland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-ireland/" title="Flag of Ireland"><img alt="Flag of Ireland" srcset="https://cdn.countryflags.com/thumbs/ireland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/ireland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/ireland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Ireland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-congo-republic-of-the/" title="Flag of Congo, Republic of the"><img alt="Flag of Congo, Republic of the" srcset="https://cdn.countryflags.com/thumbs/congo-republic-of-the/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/congo-republic-of-the/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/congo-republic-of-the/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Congo, Republic of the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-costa-rica/" title="Flag of Costa Rica"><img alt="Flag of Costa Rica" srcset="https://cdn.countryflags.com/thumbs/costa-rica/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/costa-rica/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/costa-rica/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Costa Rica</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-georgia/" title="Flag of Georgia"><img alt="Flag of Georgia" srcset="https://cdn.countryflags.com/thumbs/georgia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/georgia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/georgia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Georgia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-liberia/" title="Flag of Liberia"><img alt="Flag of Liberia" srcset="https://cdn.countryflags.com/thumbs/liberia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/liberia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/liberia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Liberia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-palestine/" title="Flag of Palestine"><img alt="Flag of Palestine" srcset="https://cdn.countryflags.com/thumbs/palestine/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/palestine/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/palestine/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Palestine</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-new-zealand/" title="Flag of New Zealand"><img alt="Flag of New Zealand" srcset="https://cdn.countryflags.com/thumbs/new-zealand/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/new-zealand/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/new-zealand/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of New Zealand</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-croatia/" title="Flag of Croatia"><img alt="Flag of Croatia" srcset="https://cdn.countryflags.com/thumbs/croatia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/croatia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/croatia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Croatia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-mauritania/" title="Flag of Mauritania"><img alt="Flag of Mauritania" srcset="https://cdn.countryflags.com/thumbs/mauritania/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/mauritania/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/mauritania/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Mauritania</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-panama/" title="Flag of Panama"><img alt="Flag of Panama" srcset="https://cdn.countryflags.com/thumbs/panama/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/panama/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/panama/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Panama</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bosnia-and-herzegovina/" title="Flag of Bosnia and Herzegovina"><img alt="Flag of Bosnia and Herzegovina" srcset="https://cdn.countryflags.com/thumbs/bosnia-and-herzegovina/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bosnia-and-herzegovina/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bosnia-and-herzegovina/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bosnia and Herzegovina</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-moldova/" title="Flag of Moldova"><img alt="Flag of Moldova" srcset="https://cdn.countryflags.com/thumbs/moldova/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/moldova/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/moldova/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Moldova</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-oman/" title="Flag of Oman"><img alt="Flag of Oman" srcset="https://cdn.countryflags.com/thumbs/oman/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/oman/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/oman/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Oman</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-uruguay/" title="Flag of Uruguay"><img alt="Flag of Uruguay" srcset="https://cdn.countryflags.com/thumbs/uruguay/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/uruguay/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/uruguay/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Uruguay</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-puerto-rico/" title="Flag of Puerto Rico"><img alt="Flag of Puerto Rico" srcset="https://cdn.countryflags.com/thumbs/puerto-rico/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/puerto-rico/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/puerto-rico/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Puerto Rico</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-mongolia/" title="Flag of Mongolia"><img alt="Flag of Mongolia" srcset="https://cdn.countryflags.com/thumbs/mongolia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/mongolia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/mongolia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Mongolia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-wales/" title="Flag of Wales"><img alt="Flag of Wales" srcset="https://cdn.countryflags.com/thumbs/wales/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/wales/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/wales/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Wales</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-albania/" title="Flag of Albania"><img alt="Flag of Albania" srcset="https://cdn.countryflags.com/thumbs/albania/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/albania/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/albania/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Albania</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-armenia/" title="Flag of Armenia"><img alt="Flag of Armenia" srcset="https://cdn.countryflags.com/thumbs/armenia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/armenia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/armenia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Armenia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-jamaica/" title="Flag of Jamaica"><img alt="Flag of Jamaica" srcset="https://cdn.countryflags.com/thumbs/jamaica/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/jamaica/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/jamaica/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Jamaica</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-kuwait/" title="Flag of Kuwait"><img alt="Flag of Kuwait" srcset="https://cdn.countryflags.com/thumbs/kuwait/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/kuwait/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/kuwait/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Kuwait</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-lithuania/" title="Flag of Lithuania"><img alt="Flag of Lithuania" srcset="https://cdn.countryflags.com/thumbs/lithuania/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/lithuania/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/lithuania/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Lithuania</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-namibia/" title="Flag of Namibia"><img alt="Flag of Namibia" srcset="https://cdn.countryflags.com/thumbs/namibia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/namibia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/namibia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Namibia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-qatar/" title="Flag of Qatar"><img alt="Flag of Qatar" srcset="https://cdn.countryflags.com/thumbs/qatar/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/qatar/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/qatar/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Qatar</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-botswana/" title="Flag of Botswana"><img alt="Flag of Botswana" srcset="https://cdn.countryflags.com/thumbs/botswana/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/botswana/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/botswana/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Botswana</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-macedonia/" title="Flag of North Macedonia"><img alt="Flag of North Macedonia" srcset="https://cdn.countryflags.com/thumbs/north-macedonia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/north-macedonia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/north-macedonia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of North Macedonia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-gambia-the/" title="Flag of Gambia, the"><img alt="Flag of Gambia, the" srcset="https://cdn.countryflags.com/thumbs/gambia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/gambia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/gambia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Gambia, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-slovenia/" title="Flag of Slovenia"><img alt="Flag of Slovenia" srcset="https://cdn.countryflags.com/thumbs/slovenia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/slovenia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/slovenia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Slovenia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-lesotho/" title="Flag of Lesotho"><img alt="Flag of Lesotho" srcset="https://cdn.countryflags.com/thumbs/lesotho/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/lesotho/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/lesotho/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Lesotho</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-latvia/" title="Flag of Latvia"><img alt="Flag of Latvia" srcset="https://cdn.countryflags.com/thumbs/latvia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/latvia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/latvia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Latvia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-kosovo/" title="Flag of Kosovo"><img alt="Flag of Kosovo" srcset="https://cdn.countryflags.com/thumbs/kosovo/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/kosovo/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/kosovo/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Kosovo</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-st-patrick/" title="Flag of Saint Patrick"><img alt="Flag of Saint Patrick" srcset="https://cdn.countryflags.com/thumbs/st-patrick/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/st-patrick/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/st-patrick/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Saint Patrick</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-northern-ireland/" title="Flag of Northern Ireland"><img alt="Flag of Northern Ireland" srcset="https://cdn.countryflags.com/thumbs/northern-ireland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/northern-ireland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/northern-ireland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Northern Ireland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-guinea-bissau/" title="Flag of Guinea-Bissau"><img alt="Flag of Guinea-Bissau" srcset="https://cdn.countryflags.com/thumbs/guinea-bissau/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/guinea-bissau/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/guinea-bissau/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Guinea-Bissau</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-gabon/" title="Flag of Gabon"><img alt="Flag of Gabon" srcset="https://cdn.countryflags.com/thumbs/gabon/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/gabon/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/gabon/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Gabon</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-swaziland/" title="Flag of Swaziland"><img alt="Flag of Swaziland" srcset="https://cdn.countryflags.com/thumbs/swaziland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/swaziland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/swaziland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Swaziland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bahrain/" title="Flag of Bahrain"><img alt="Flag of Bahrain" srcset="https://cdn.countryflags.com/thumbs/bahrain/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bahrain/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bahrain/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bahrain</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-mauritius/" title="Flag of Mauritius"><img alt="Flag of Mauritius" srcset="https://cdn.countryflags.com/thumbs/mauritius/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/mauritius/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/mauritius/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Mauritius</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-east-timor/" title="Flag of East Timor"><img alt="Flag of East Timor" srcset="https://cdn.countryflags.com/thumbs/east-timor/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/east-timor/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/east-timor/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of East Timor</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-estonia/" title="Flag of Estonia"><img alt="Flag of Estonia" srcset="https://cdn.countryflags.com/thumbs/estonia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/estonia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/estonia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Estonia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-cyprus/" title="Flag of Cyprus"><img alt="Flag of Cyprus" srcset="https://cdn.countryflags.com/thumbs/cyprus/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/cyprus/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/cyprus/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Cyprus</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-trinidad-and-tobago/" title="Flag of Trinidad and Tobago"><img alt="Flag of Trinidad and Tobago" srcset="https://cdn.countryflags.com/thumbs/trinidad-and-tobago/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/trinidad-and-tobago/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/trinidad-and-tobago/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Trinidad and Tobago</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-fiji/" title="Flag of Fiji"><img alt="Flag of Fiji" srcset="https://cdn.countryflags.com/thumbs/fiji/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/fiji/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/fiji/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Fiji</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-djibouti/" title="Flag of Djibouti"><img alt="Flag of Djibouti" srcset="https://cdn.countryflags.com/thumbs/djibouti/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/djibouti/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/djibouti/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Djibouti</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-comoros/" title="Flag of Comoros"><img alt="Flag of Comoros" srcset="https://cdn.countryflags.com/thumbs/comoros/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/comoros/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/comoros/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Comoros</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-equatorial-guinea/" title="Flag of Equatorial Guinea"><img alt="Flag of Equatorial Guinea" srcset="https://cdn.countryflags.com/thumbs/equatorial-guinea/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/equatorial-guinea/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/equatorial-guinea/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Equatorial Guinea</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bhutan/" title="Flag of Bhutan"><img alt="Flag of Bhutan" srcset="https://cdn.countryflags.com/thumbs/bhutan/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bhutan/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bhutan/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bhutan</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-guyana/" title="Flag of Guyana"><img alt="Flag of Guyana" srcset="https://cdn.countryflags.com/thumbs/guyana/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/guyana/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/guyana/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Guyana</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-solomon-islands-the/" title="Flag of Solomon Islands, the"><img alt="Flag of Solomon Islands, the" srcset="https://cdn.countryflags.com/thumbs/solomon-islands/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/solomon-islands/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/solomon-islands/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Solomon Islands, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-montenegro/" title="Flag of Montenegro"><img alt="Flag of Montenegro" srcset="https://cdn.countryflags.com/thumbs/montenegro/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/montenegro/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/montenegro/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Montenegro</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-macao/" title="Flag of Macao"><img alt="Flag of Macao" srcset="https://cdn.countryflags.com/thumbs/macau/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/macau/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/macau/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Macao</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-luxembourg/" title="Flag of Luxembourg"><img alt="Flag of Luxembourg" srcset="https://cdn.countryflags.com/thumbs/luxembourg/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/luxembourg/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/luxembourg/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Luxembourg</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-suriname/" title="Flag of Suriname"><img alt="Flag of Suriname" srcset="https://cdn.countryflags.com/thumbs/suriname/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/suriname/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/suriname/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Suriname</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-cape-verde/" title="Flag of Cape Verde"><img alt="Flag of Cape Verde" srcset="https://cdn.countryflags.com/thumbs/cape-verde/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/cape-verde/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/cape-verde/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Cape Verde</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-brunei/" title="Flag of Brunei"><img alt="Flag of Brunei" srcset="https://cdn.countryflags.com/thumbs/brunei/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/brunei/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/brunei/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Brunei</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-malta/" title="Flag of Malta"><img alt="Flag of Malta" srcset="https://cdn.countryflags.com/thumbs/malta/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/malta/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/malta/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Malta</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-guadeloupe/" title="Flag of Guadeloupe"><img alt="Flag of Guadeloupe" srcset="https://cdn.countryflags.com/thumbs/guadeloupe/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/guadeloupe/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/guadeloupe/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Guadeloupe</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-maldives-the/" title="Flag of Maldives, the"><img alt="Flag of Maldives, the" srcset="https://cdn.countryflags.com/thumbs/maldives/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/maldives/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/maldives/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Maldives, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-belize/" title="Flag of Belize"><img alt="Flag of Belize" srcset="https://cdn.countryflags.com/thumbs/belize/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/belize/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/belize/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Belize</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-iceland/" title="Flag of Iceland"><img alt="Flag of Iceland" srcset="https://cdn.countryflags.com/thumbs/iceland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/iceland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/iceland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Iceland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bahamas-the/" title="Flag of Bahamas, the"><img alt="Flag of Bahamas, the" srcset="https://cdn.countryflags.com/thumbs/bahamas/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bahamas/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bahamas/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bahamas, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-barbados/" title="Flag of Barbados"><img alt="Flag of Barbados" srcset="https://cdn.countryflags.com/thumbs/barbados/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/barbados/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/barbados/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Barbados</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/vanuatu-flag/" title="Flag of Vanuatu"><img alt="Flag of Vanuatu" srcset="https://cdn.countryflags.com/thumbs/vanuatu/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/vanuatu/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/vanuatu/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Vanuatu</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-new-caledonia/" title="Flag of New Caledonia"><img alt="Flag of New Caledonia" srcset="https://cdn.countryflags.com/thumbs/new-caledonia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/new-caledonia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/new-caledonia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of New Caledonia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-sao-tome-and-principe/" title="Flag of São Tomé and Príncipe"><img alt="Flag of São Tomé and Príncipe" srcset="https://cdn.countryflags.com/thumbs/sao-tome-and-principe/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/sao-tome-and-principe/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/sao-tome-and-principe/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of São Tomé and Príncipe</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-samoa/" title="Flag of Samoa"><img alt="Flag of Samoa" srcset="https://cdn.countryflags.com/thumbs/samoa/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/samoa/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/samoa/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Samoa</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-guam/" title="Flag of Guam"><img alt="Flag of Guam" srcset="https://cdn.countryflags.com/thumbs/guam/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/guam/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/guam/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Guam</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-saint-lucia/" title="Flag of Saint Lucia"><img alt="Flag of Saint Lucia" srcset="https://cdn.countryflags.com/thumbs/saint-lucia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/saint-lucia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/saint-lucia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Saint Lucia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-curacao/" title="Flag of Curaçao"><img alt="Flag of Curaçao" srcset="https://cdn.countryflags.com/thumbs/curacao/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/curacao/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/curacao/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Curaçao</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/aruba-flag/" title="Flag of Aruba"><img alt="Flag of Aruba" srcset="https://cdn.countryflags.com/thumbs/aruba/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/aruba/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/aruba/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Aruba</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-grenada/" title="Flag of Grenada"><img alt="Flag of Grenada" srcset="https://cdn.countryflags.com/thumbs/grenada/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/grenada/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/grenada/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Grenada</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-kiribati/" title="Flag of Kiribati"><img alt="Flag of Kiribati" srcset="https://cdn.countryflags.com/thumbs/kiribati/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/kiribati/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/kiribati/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Kiribati</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-tonga/" title="Flag of Tonga"><img alt="Flag of Tonga" srcset="https://cdn.countryflags.com/thumbs/tonga/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/tonga/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/tonga/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Tonga</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-micronesia/" title="Flag of Micronesia"><img alt="Flag of Micronesia" srcset="https://cdn.countryflags.com/thumbs/micronesia/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/micronesia/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/micronesia/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Micronesia</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-saint-vincent-and-the-grenadines/" title="Flag of Saint Vincent and the Grenadines"><img alt="Flag of Saint Vincent and the Grenadines" srcset="https://cdn.countryflags.com/thumbs/saint-vincent-and-the-grenadines/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/saint-vincent-and-the-grenadines/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/saint-vincent-and-the-grenadines/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Saint Vincent and the Grenadines</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-antigua-and-barbuda/" title="Flag of Antigua and Barbuda"><img alt="Flag of Antigua and Barbuda" srcset="https://cdn.countryflags.com/thumbs/antigua-and-barbuda/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/antigua-and-barbuda/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/antigua-and-barbuda/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Antigua and Barbuda</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-seychelles-the/" title="Flag of Seychelles, the"><img alt="Flag of Seychelles, the" srcset="https://cdn.countryflags.com/thumbs/seychelles/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/seychelles/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/seychelles/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Seychelles, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-andorra/" title="Flag of Andorra"><img alt="Flag of Andorra" srcset="https://cdn.countryflags.com/thumbs/andorra/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/andorra/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/andorra/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Andorra</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-marshall-islands-the/" title="Flag of Marshall Islands, the"><img alt="Flag of Marshall Islands, the" srcset="https://cdn.countryflags.com/thumbs/marshall-islands/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/marshall-islands/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/marshall-islands/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Marshall Islands, the</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-dominica/" title="Flag of Dominica"><img alt="Flag of Dominica" srcset="https://cdn.countryflags.com/thumbs/dominica/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/dominica/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/dominica/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Dominica</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-greenland/" title="Flag of Greenland"><img alt="Flag of Greenland" srcset="https://cdn.countryflags.com/thumbs/greenland/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/greenland/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/greenland/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Greenland</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-saint-kitts-and-nevis/" title="Flag of Saint Kitts and Nevis"><img alt="Flag of Saint Kitts and Nevis" srcset="https://cdn.countryflags.com/thumbs/saint-kitts-and-nevis/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/saint-kitts-and-nevis/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/saint-kitts-and-nevis/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Saint Kitts and Nevis</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-the-northern-mariana-islands/" title="Flag of the Northern Mariana Islands"><img alt="Flag of the Northern Mariana Islands" srcset="https://cdn.countryflags.com/thumbs/northern-mariana-islands/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/northern-mariana-islands/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/northern-mariana-islands/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of the Northern Mariana Islands</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-the-faroe-islands/" title="Flag of the Faroe Islands"><img alt="Flag of the Faroe Islands" srcset="https://cdn.countryflags.com/thumbs/faroe-islands/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/faroe-islands/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/faroe-islands/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of the Faroe Islands</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-st-martin/" title="Flag of St. Martin"><img alt="Flag of St. Martin" srcset="https://cdn.countryflags.com/thumbs/st-martin/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/st-martin/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/st-martin/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of St. Martin</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-liechtenstein/" title="Flag of Liechtenstein"><img alt="Flag of Liechtenstein" srcset="https://cdn.countryflags.com/thumbs/liechtenstein/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/liechtenstein/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/liechtenstein/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Liechtenstein</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-san-marino/" title="Flag of San Marino"><img alt="Flag of San Marino" srcset="https://cdn.countryflags.com/thumbs/san-marino/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/san-marino/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/san-marino/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of San Marino</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-monaco/" title="Flag of Monaco"><img alt="Flag of Monaco" srcset="https://cdn.countryflags.com/thumbs/monaco/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/monaco/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/monaco/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Monaco</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-palau/" title="Flag of Palau"><img alt="Flag of Palau" srcset="https://cdn.countryflags.com/thumbs/palau/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/palau/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/palau/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Palau</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-bonaire/" title="Flag of Bonaire"><img alt="Flag of Bonaire" srcset="https://cdn.countryflags.com/thumbs/bonaire/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/bonaire/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/bonaire/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Bonaire</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-tuvalu/" title="Flag of Tuvalu"><img alt="Flag of Tuvalu" srcset="https://cdn.countryflags.com/thumbs/tuvalu/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/tuvalu/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/tuvalu/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Tuvalu</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-nauru/" title="Flag of Nauru"><img alt="Flag of Nauru" srcset="https://cdn.countryflags.com/thumbs/nauru/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/nauru/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/nauru/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Nauru</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-st-eustatius/" title="Flag of St. Eustatius"><img alt="Flag of St. Eustatius" srcset="https://cdn.countryflags.com/thumbs/st-eustatius/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/st-eustatius/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/st-eustatius/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of St. Eustatius</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-saba/" title="Flag of Saba"><img alt="Flag of Saba" srcset="https://cdn.countryflags.com/thumbs/saba/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/saba/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/saba/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Saba</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-niue/" title="Flag of Niue"><img alt="Flag of Niue" srcset="https://cdn.countryflags.com/thumbs/niue/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/niue/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/niue/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Niue</span></a></div>
	<div class="thumb"><a href="https://www.countryflags.com/flag-of-vatican-city/" title="Flag of Vatican City"><img alt="Flag of Vatican City" srcset="https://cdn.countryflags.com/thumbs/vatican-city/flag-square-500.png 2x, https://cdn.countryflags.com/thumbs/vatican-city/flag-square-250.png" src="https://cdn.countryflags.com/thumbs/vatican-city/flag-square-250.png" loading="lazy" width="120"><span class="title">Flag of Vatican City</span></a></div>
</div>
"""

NAME_FIXES = {
    "united states, the": "united states",
    "united states of america": "united states",
    "philippines, the": "philippines",
    "congo, democratic republic of the": "democratic republic of the congo",
    "democratic republic of congo": "democratic republic of the congo",
    "dr congo": "democratic republic of the congo",
    "united kingdom, the": "united kingdom",
    "uk": "united kingdom",
    "u.k.": "united kingdom",
    "korea, south": "south korea",
    "republic of korea": "south korea",
    "korea, north": "north korea",
    "democratic people's republic of korea": "north korea",
    "netherlands, the": "netherlands",
    "central-african republic, the": "central african republic",
    "congo, republic of the": "republic of the congo",
    "dominican republic, the": "dominican republic",
    "czech republic, the": "czech republic",
    "gambia, the": "the gambia",
    "maldives, the": "maldives",
    "solomon islands, the": "solomon islands",
    "marshall islands, the": "marshall islands",
    "seychelles, the": "seychelles",
    "bahamas, the": "the bahamas",
    "st. martin": "saint martin",
    "swaziland": "eswatini",
    "côte d' ivoire": "ivory coast",
    "côte d’ ivoire": "ivory coast",
    "cote d'ivoire": "ivory coast",
    "cote d ivoire": "ivory coast",
    "east timor": "timor-leste",
    "macao": "macau",
    "macedonia": "north macedonia",
    "hong kong sar": "hong kong",
    "uae": "united arab emirates",
    "united arab emirates, the": "united arab emirates",
}


class FlagHTMLParser(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.entries = []
        self._current_title = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        if tag == "a":
            title = attrs_dict.get("title")
            if title and title.startswith("Flag of "):
                self._current_title = title[len("Flag of ") :].strip()
        elif tag == "img" and self._current_title:
            srcset = attrs_dict.get("srcset", "")
            src = attrs_dict.get("src", "")
            self.entries.append((self._current_title, pick_high_res(srcset, src)))
            self._current_title = None


def pick_high_res(srcset: str, fallback_src: str) -> str:
    for part in srcset.split(","):
        match = re.search(r"(https://\S+-500\.png)", part.strip())
        if match:
            return match.group(1)
    return fallback_src


def resolve_node_bin() -> str:
    node_bin = shutil.which("node")
    if node_bin:
        return node_bin

    nvm_root = Path.home() / ".config" / "nvm" / "versions" / "node"
    if nvm_root.exists():
        versions = sorted(nvm_root.iterdir(), reverse=True)
        for version_dir in versions:
            candidate = version_dir / "bin" / "node"
            if candidate.exists():
                return str(candidate)

    raise RuntimeError("Node runtime not found. Install Node or add it to PATH before running this script.")


def wrangler_cmd() -> list[str]:
    return [resolve_node_bin(), str(WRANGLER_BIN)]


def normalize_name(value: str) -> str:
    text = value.strip().lower()
    text = text.replace("’", "'")
    text = re.sub(r"\s+", " ", text)
    text = text.replace("&", "and")
    text = re.sub(r"[().]", "", text)
    text = re.sub(r"\s*,\s*", ", ", text)
    text = NAME_FIXES.get(text, text)
    if text.startswith("the "):
        without_the = text[4:]
        if without_the in NAME_FIXES:
            text = NAME_FIXES[without_the]
        else:
            text = without_the
    return text.strip()


def slugify(value: str) -> str:
    text = normalize_name(value)
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = text.replace("'", "")
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = re.sub(r"-+", "-", text).strip("-")
    return text or "flag"


def parse_flag_map() -> dict[str, str]:
    parser = FlagHTMLParser()
    parser.feed(HTML_SOURCE)
    parsed = {}
    for raw_name, url in parser.entries:
        parsed[normalize_name(raw_name)] = url
    return parsed


def answer_candidates(answer: str) -> list[str]:
    raw_parts = [part.strip() for part in answer.split(";") if part.strip()]
    if not raw_parts:
        raw_parts = [answer.strip()]

    candidates: list[str] = []
    for raw in raw_parts:
        candidate = normalize_name(raw)
        variants = {
            candidate,
            candidate.replace("flag of ", "").strip(),
            candidate.replace("coat of arms of ", "").strip(),
        }
        for variant in list(variants):
            if variant.startswith("the "):
                variants.add(variant[4:].strip())
        for variant in variants:
            if variant and variant not in candidates:
                candidates.append(variant)
    return candidates


def run_cmd(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
    )
    if check and result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        detail = stderr or stdout or f"exit code {result.returncode}"
        raise RuntimeError(f"{' '.join(cmd)} failed: {detail}")
    return result


def fetch_subject() -> dict | None:
    sql = (
        "SELECT id, name FROM subjects "
        f"WHERE id = '{SUBJECT_ID}' OR lower(name) = lower('{SUBJECT_NAME}') LIMIT 1"
    )
    result = run_cmd(
        wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
    )
    payload = json.loads(result.stdout)
    rows = payload[0]["results"]
    return rows[0] if rows else None


def fetch_cards() -> list[dict]:
    sql = (
        "SELECT id, answer, images_base FROM cards "
        f"WHERE subject_id = '{SUBJECT_ID}' ORDER BY answer"
    )
    result = run_cmd(
        wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
    )
    payload = json.loads(result.stdout)
    return payload[0]["results"]


def collect_logged_global_objects(card_ids: set[str]) -> dict[str, str]:
    if not WRANGLER_LOG_DIR.exists():
        raise RuntimeError(f"Wrangler log directory not found: {WRANGLER_LOG_DIR}")

    chosen: dict[str, tuple[int, str]] = {}
    for log_path in sorted(WRANGLER_LOG_DIR.glob("wrangler-*.log")):
        try:
            text = log_path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue

        for match in GLOBAL_OBJECT_PATTERN.finditer(text):
            card_id = match.group("card_id")
            if card_id not in card_ids:
                continue
            timestamp = int(match.group("ts"))
            object_path = match.group(0)
            current = chosen.get(card_id)
            if current is None or timestamp < current[0]:
                chosen[card_id] = (timestamp, object_path)

    return {card_id: data[1] for card_id, data in chosen.items()}


def download_image(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Aliolo flag sync"})
    with urllib.request.urlopen(request) as response, open(destination, "wb") as handle:
        handle.write(response.read())


def upload_to_r2(card_id: str, matched_candidate: str, file_path: Path) -> str:
    file_name = f"{slugify(matched_candidate)}.png"
    r2_key = f"cards/{card_id}/{file_name}"
    run_cmd(
        wrangler_cmd() + ["r2", "object", "put", f"{R2_BUCKET}/{r2_key}", "--file", str(file_path)],
    )
    return r2_key


def update_card(card_id: str, public_url: str) -> None:
    images_json = json.dumps([public_url]).replace("'", "''")
    sql = (
        "UPDATE cards "
        f"SET images_base = '{images_json}', updated_at = CURRENT_TIMESTAMP "
        f"WHERE id = '{card_id}'"
    )
    run_cmd(
        wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"],
    )


def write_report(rows: list[dict], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "status",
        "card_id",
        "answer",
        "matched_candidate",
        "source_url",
        "r2_key",
        "public_url",
        "error",
    ]
    with open(output_path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in fieldnames})


def process_cards(dry_run: bool, limit: int | None, report_path: Path | None) -> int:
    subject = fetch_subject()
    if not subject:
        raise RuntimeError(f"Subject not found for id/name: {SUBJECT_ID} / {SUBJECT_NAME}")
    print(f"Subject: {subject['name']} ({subject['id']})")
    if subject["id"] != SUBJECT_ID:
        raise RuntimeError(f"Resolved unexpected subject id {subject['id']} for {subject['name']}")

    flag_map = parse_flag_map()
    print(f"Parsed {len(flag_map)} flag mappings from HTML source.")

    cards = fetch_cards()
    print(f"Fetched {len(cards)} cards from D1.")
    if limit is not None:
        cards = cards[:limit]
        print(f"Processing limited subset: {len(cards)} cards.")

    TMP_DIR.mkdir(exist_ok=True)
    report_rows: list[dict] = []
    summary = {"matched": 0, "updated": 0, "skipped": 0, "failed": 0}

    for card in cards:
        card_id = card["id"]
        answer = (card.get("answer") or "").strip()
        candidates = answer_candidates(answer)

        matched_candidate = None
        source_url = None
        for candidate in candidates:
            source_url = flag_map.get(candidate)
            if source_url:
                matched_candidate = candidate
                break

        if not source_url:
            summary["skipped"] += 1
            print(f"SKIP   {answer}")
            report_rows.append(
                {
                    "status": "skipped",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": "",
                    "source_url": "",
                    "r2_key": "",
                    "public_url": "",
                    "error": "No source match",
                }
            )
            continue

        summary["matched"] += 1
        print(f"MATCH  {answer} -> {matched_candidate}")
        if dry_run:
            report_rows.append(
                {
                    "status": "matched",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": matched_candidate,
                    "source_url": source_url,
                    "r2_key": "",
                    "public_url": "",
                    "error": "",
                }
            )
            continue

        tmp_file = TMP_DIR / f"{card_id}.png"
        try:
            download_image(source_url, tmp_file)
            r2_key = upload_to_r2(card_id, matched_candidate, tmp_file)
            public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
            update_card(card_id, public_url)
            summary["updated"] += 1
            print(f"UPDATE {answer} -> {public_url}")
            report_rows.append(
                {
                    "status": "updated",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": matched_candidate,
                    "source_url": source_url,
                    "r2_key": r2_key,
                    "public_url": public_url,
                    "error": "",
                }
            )
        except (RuntimeError, urllib.error.URLError, OSError) as exc:
            summary["failed"] += 1
            print(f"FAIL   {answer}: {exc}", file=sys.stderr)
            report_rows.append(
                {
                    "status": "failed",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": matched_candidate or "",
                    "source_url": source_url,
                    "r2_key": "",
                    "public_url": "",
                    "error": str(exc),
                }
            )
        finally:
            if tmp_file.exists():
                tmp_file.unlink()

    if report_path:
        write_report(report_rows, report_path)
        print(f"Report written to {report_path}")

    print(
        "Summary: "
        f"matched={summary['matched']} "
        f"updated={summary['updated']} "
        f"skipped={summary['skipped']} "
        f"failed={summary['failed']}"
    )
    return 0 if summary["failed"] == 0 else 1


def relink_cards_from_logs(dry_run: bool, limit: int | None, report_path: Path | None) -> int:
    subject = fetch_subject()
    if not subject:
        raise RuntimeError(f"Subject not found for id/name: {SUBJECT_ID} / {SUBJECT_NAME}")
    print(f"Subject: {subject['name']} ({subject['id']})")
    if subject["id"] != SUBJECT_ID:
        raise RuntimeError(f"Resolved unexpected subject id {subject['id']} for {subject['name']}")

    cards = fetch_cards()
    print(f"Fetched {len(cards)} cards from D1.")
    if limit is not None:
        cards = cards[:limit]
        print(f"Processing limited subset: {len(cards)} cards.")

    card_ids = {card["id"] for card in cards}
    logged_objects = collect_logged_global_objects(card_ids)
    print(f"Found logged global objects for {len(logged_objects)} cards.")

    summary = {"updated": 0, "skipped": 0, "failed": 0}
    report_rows: list[dict] = []

    for card in cards:
        card_id = card["id"]
        answer = (card.get("answer") or "").strip()
        object_path = logged_objects.get(card_id)
        if not object_path:
            summary["skipped"] += 1
            print(f"SKIP   {answer}")
            report_rows.append(
                {
                    "status": "skipped",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": "",
                    "source_url": "",
                    "r2_key": "",
                    "public_url": "",
                    "error": "No logged global object path found",
                }
            )
            continue

        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{object_path}"
        if dry_run:
            print(f"MATCH  {answer} -> {public_url}")
            report_rows.append(
                {
                    "status": "matched",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": "",
                    "source_url": "",
                    "r2_key": object_path,
                    "public_url": public_url,
                    "error": "",
                }
            )
            continue

        try:
            update_card(card_id, public_url)
            summary["updated"] += 1
            print(f"UPDATE {answer} -> {public_url}")
            report_rows.append(
                {
                    "status": "updated",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": "",
                    "source_url": "",
                    "r2_key": object_path,
                    "public_url": public_url,
                    "error": "",
                }
            )
        except RuntimeError as exc:
            summary["failed"] += 1
            print(f"FAIL   {answer}: {exc}", file=sys.stderr)
            report_rows.append(
                {
                    "status": "failed",
                    "card_id": card_id,
                    "answer": answer,
                    "matched_candidate": "",
                    "source_url": "",
                    "r2_key": object_path,
                    "public_url": public_url,
                    "error": str(exc),
                }
            )

    if report_path:
        write_report(report_rows, report_path)
        print(f"Report written to {report_path}")

    print(
        "Summary: "
        f"updated={summary['updated']} "
        f"skipped={summary['skipped']} "
        f"failed={summary['failed']}"
    )
    return 0 if summary["failed"] == 0 else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Upload flag images for Aliolo cards.")
    parser.add_argument("--dry-run", action="store_true", help="Show matches without mutating D1/R2.")
    parser.add_argument("--limit", type=int, default=None, help="Process only the first N cards.")
    parser.add_argument(
        "--relink-from-logs",
        action="store_true",
        help="Rewrite images_base to the earliest logged global_* object path for each card.",
    )
    parser.add_argument(
        "--report",
        default=str(SCRIPT_DIR / ".tmp" / "upload_flags_report.csv"),
        help="CSV path for per-card results.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report_path = Path(args.report) if args.report else None
    try:
        if args.relink_from_logs:
            return relink_cards_from_logs(dry_run=args.dry_run, limit=args.limit, report_path=report_path)
        return process_cards(dry_run=args.dry_run, limit=args.limit, report_path=report_path)
    except Exception as exc:
        print(f"Fatal error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
