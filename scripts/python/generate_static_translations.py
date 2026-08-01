#!/usr/bin/env python3
import os
import re
import sys
import json
import time
import urllib.request
import urllib.parse
from pathlib import Path

# Supported languages list
SUPPORTED_LANGUAGES = [
    "en", "id", "bg", "cs", "da", "de", "et", "es", "fr", "ga", "hr", "it", "lv", "lt", 
    "hu", "mt", "nl", "pl", "pt", "ro", "sk", "sl", "fi", "sv", "tl", "vi", "tr", "el", 
    "uk", "ar", "hi", "zh", "ja", "ko"
]

print(f"Checking application languages: {len(SUPPORTED_LANGUAGES)} languages supported.")
print(f"Supported list: {', '.join(SUPPORTED_LANGUAGES)}")

# Source English content dictionary
ENGLISH_CONTENT = {
    # Layout common
    "legal_info": "Legal information",
    "last_updated": "Last updated",
    "support": "Support",
    "home": "Home",
    "privacy": "Privacy",
    "terms": "Terms",
    "refunds": "Refunds",
    "pricing": "Pricing",
    
    # Privacy Policy
    "privacy_title": "Aliolo Privacy Policy",
    "privacy_subtitle": "How Aliolo collects, uses, stores, and protects account, learning, and payment-related information.",
    "privacy_body": """<h2>Information We Collect</h2>
<p>We collect the information needed to operate Aliolo, including account details such as email address, username, password authentication data, avatar settings, preferences, and profile settings.</p>
<p>We also store learning activity such as subjects, folders, collections, cards, progress, streaks, daily goals, test and learn settings, feedback, and basic app usage events needed to provide the learning experience.</p>
<h2>How We Use Information</h2>
<p>We use this information to create and secure your account, synchronize your learning data, personalize your study experience, provide premium access, respond to support requests, improve the app, and prevent misuse or service abuse.</p>
<h2>Payments and Subscriptions</h2>
<p>Aliolo does not directly store complete payment card details. Web payments are processed by Paddle, and mobile purchases may be processed by Google Play or Apple App Store when those purchase channels are available.</p>
<p>For subscription access, we may store payment-provider identifiers, product identifiers, subscription status, renewal period dates, and related webhook or transaction metadata. This lets us activate, renew, cancel, or restore premium access.</p>
<h2>Third-Party Services</h2>
<p>We use service providers for hosting, infrastructure, storage, analytics or operational logs, authentication, and payments. These providers process information only as needed to provide their services to Aliolo.</p>
<div class="notice"><strong>Paddle notice:</strong> Our order process may be conducted by Paddle.com, our online reseller and Merchant of Record. Paddle handles payment processing, tax calculation where applicable, payment security, and payment-related customer service.</div>
<h2>Cookies and Local Storage</h2>
<p>Aliolo may use cookies, session identifiers, browser storage, or similar technologies to keep you signed in, remember preferences, secure the service, and operate the web app.</p>
<h2>Data Retention and Deletion</h2>
<p>We keep account and learning data while your account is active or as needed to provide the service, comply with legal obligations, resolve disputes, prevent abuse, and maintain transaction records. You may request account deletion or data-related support by contacting us.</p>
<h2>Children and Education Use</h2>
<p>Aliolo is an educational product. If a parent, guardian, or school believes that a child has provided personal information without appropriate permission, contact us so we can review and take appropriate action.</p>
<h2>Security</h2>
<p>We use reasonable technical and organizational safeguards to protect personal information. No online service can guarantee perfect security, but we work to limit access and protect data from unauthorized use.</p>
<h2>Your Choices and Rights</h2>
<p>Depending on your location, you may have rights to access, correct, delete, export, or restrict use of your personal information. Contact us at <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a> to make a request.</p>""",

    # Terms & Conditions
    "terms_title": "Aliolo Subscription Terms",
    "terms_subtitle": "The rules for Aliolo accounts, premium access, subscription billing, cancellation, and acceptable use.",
    "terms_body": """<h2>Using Aliolo</h2>
<p>Aliolo provides visual learning tools, curated educational content, flashcards, progress tracking, and premium learning features. You are responsible for keeping your account credentials secure and for using the service lawfully.</p>
<h2>Premium Access</h2>
<p>Premium access unlocks paid features shown in the app or on the pricing page. Available features may change as the product improves, but active subscribers will continue to receive access to the paid Aliolo experience during their valid subscription period.</p>
<h2>Billing and Renewal</h2>
<p>Subscriptions renew automatically unless canceled before the end of the current billing period. Prices, billing cadence, taxes, local currency conversion, and renewal rules are shown at checkout and may vary by purchase channel, region, platform, or active offer.</p>
<div class="notice"><strong>Paddle notice:</strong> For web purchases, our order process may be conducted by Paddle.com. Paddle.com is the Merchant of Record for those orders and provides payment-related customer service, tax handling, and returns processing.</div>
<h2>Cancellation</h2>
<p>You can cancel according to the rules of the purchase channel you used. Cancellation stops future renewal. Unless the purchase channel states otherwise, paid access remains available until the end of the current billing period.</p>
<h2>Refunds</h2>
<p>Refunds are handled according to our <a href="/refund">Refund Policy</a>, the purchase channel rules, and applicable consumer law. App store purchases are normally handled by the relevant app store.</p>
<h2>Acceptable Use</h2>
<p>You may not misuse Aliolo, interfere with the service, attempt unauthorized access, scrape or copy content at scale, reverse engineer protected parts of the app, upload unlawful material, or use the service in a way that harms other users or Aliolo.</p>
<h2>Content and Availability</h2>
<p>Aliolo may update, add, remove, or reorganize subjects, cards, features, and design. We aim to keep the service reliable, but availability can be affected by maintenance, third-party providers, network issues, or product changes.</p>
<h2>Disclaimer and Liability</h2>
<p>Aliolo is provided as an educational and study-support tool. We do not guarantee specific learning, exam, professional, or financial outcomes. To the maximum extent permitted by law, Aliolo is provided without warranties beyond those required by applicable law.</p>
<h2>Changes to These Terms</h2>
<p>We may update these terms to reflect product, legal, billing, or operational changes. The current version is published on this page.</p>""",

    # Refund Policy
    "refund_title": "Aliolo Refund Policy",
    "refund_subtitle": "How refunds, cancellations, chargebacks, and payment support work for Aliolo Premium.",
    "refund_body": """<h2>Overview</h2>
<p>Aliolo Premium is a digital subscription. Because premium access can be activated immediately, purchases are generally final once the subscription is active and used, except where this policy, the purchase channel, or applicable law provides otherwise.</p>
<h2>7-Day Refund Window</h2>
<p>If you accidentally purchased a web subscription or have a technical issue that prevents you from using premium features, you may request a refund within 7 days of the initial purchase. Include the account email, order details, and a short description of the issue.</p>
<h2>No Prorated Mid-Cycle Refunds</h2>
<p>We do not generally provide prorated refunds for cancellations after the initial refund window. If you cancel after that period, you will normally keep premium access until the end of the paid billing period.</p>
<h2>Purchase Channel Rules</h2>
<p>Refunds for purchases made through Google Play or Apple App Store must usually be requested through the relevant app store. Those platforms apply their own refund rules and review process.</p>
<div class="notice"><strong>Paddle notice:</strong> For web orders, Paddle.com may act as Merchant of Record. Paddle handles payment-related customer service, tax handling, and returns processing for those orders.</div>
<h2>How to Request a Refund</h2>
<p>For web orders, contact Paddle buyer support using the order information from your receipt, or contact Aliolo support at <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a>. We may direct payment-specific requests to Paddle when Paddle is the Merchant of Record.</p>
<h2>Chargebacks and Abuse</h2>
<p>If a payment is reversed, disputed, refunded, or identified as fraudulent, Aliolo may suspend or remove premium access associated with that transaction.</p>""",

    # Pricing Page
    "pricing_title": "Aliolo Premium Pricing",
    "pricing_subtitle": "Simple subscription options for unlocking the full Aliolo visual learning experience.",
    "pricing_body": """<div class="plans">
<section class="plan">
<span class="tag">Flexible</span>
<h2>Weekly</h2>
<div class="price">$2.99</div>
<p>Per week. Useful for short-term studying, review, or exam preparation.</p>
</section>
<section class="plan">
<span class="tag">Popular</span>
<h2>Monthly</h2>
<div class="price">$8.99</div>
<p>Per month. Best for consistent learning without a long commitment.</p>
</section>
<section class="plan">
<span class="tag">Best value</span>
<h2>Yearly</h2>
<div class="price">$80.99</div>
<p>Per year. Lower effective monthly cost for long-term learners.</p>
</section>
</div>
<h2>What Premium Includes</h2>
<ul>
<li>Full access to premium curated subjects and learning libraries.</li>
<li>Advanced spaced repetition and progress tracking features.</li>
<li>Custom flashcard, subject, folder, and collection creation where available.</li>
<li>Interactive learn and test modes, including autoplay settings.</li>
<li>Private learning organization features for personal study workflows.</li>
</ul>
<h2>Billing Details</h2>
<p>Prices are listed in USD for this public pricing page. Checkout may show local currency, taxes, and final billing details depending on your location, payment method, and purchase channel.</p>
<p>Subscriptions renew automatically until canceled. You can cancel according to the rules of the channel where you purchased. Access normally continues until the end of the paid billing period.</p>
<div class="notice"><strong>Paddle notice:</strong> Web orders may be processed by Paddle.com, our online reseller and Merchant of Record. Paddle may calculate and collect applicable taxes and provide payment-related buyer support.</div>
<div class="comparison-card">
<h2>Free vs Premium Comparison</h2>
<p>This table matches the current app experience and makes the premium upgrade easier to evaluate at a glance.</p>
<table class="comparison-table" aria-label="Aliolo free and premium feature comparison">
<thead>
<tr>
<th>Feature</th>
<th>Free</th>
<th>Premium</th>
</tr>
</thead>
<tbody>
<tr>
<td>Full library</td>
<td><span class="comparison-check">✓</span></td>
<td><span class="comparison-check pro">✓</span></td>
</tr>
<tr>
<td>Spaced repetition</td>
<td><span class="comparison-cross">✕</span></td>
<td><span class="comparison-check pro">✓</span></td>
</tr>
<tr>
<td>Creation</td>
<td><span class="comparison-cross">✕</span></td>
<td><span class="comparison-check pro">✓</span></td>
</tr>
<tr>
<td>Testing</td>
<td><span class="comparison-cross">✕</span></td>
<td><span class="comparison-check pro">✓</span></td>
</tr>
<tr>
<td>Autoplay</td>
<td><span class="comparison-cross">✕</span></td>
<td><span class="comparison-check pro">✓</span></td>
</tr>
<tr>
<td>Private mode</td>
<td><span class="comparison-cross">✕</span></td>
<td><span class="comparison-check pro">✓</span></td>
</tr>
<tr>
<td>Customize</td>
<td><span class="comparison-cross">✕</span></td>
<td><span class="comparison-check pro">✓</span></td>
</tr>
</tbody>
</table>
<div class="comparison-note">Premium unlocks the full study workflow: adaptive review, creation tools, advanced testing, autoplay controls, private organization, and deeper personalization.</div>
</div>
<h2>Platform Price Differences</h2>
<p>Prices and offers may vary between web checkout, Google Play, Apple App Store, countries, currencies, and limited-time promotions. The final checkout screen controls the actual price and renewal terms for your purchase.</p>
<h2>Related Policies</h2>
<p>Before subscribing, review the <a href="/terms">Subscription Terms</a>, <a href="/refund">Refund Policy</a>, and <a href="/privacy">Privacy Policy</a>.</p>""",

    # Checkout Page
    "checkout_title": "Aliolo Checkout",
    "checkout_subtitle": "Secure checkout for Aliolo Premium subscriptions.",
    "checkout_eyebrow": "Secure checkout",
    "checkout_h1": "Complete your Aliolo Premium purchase.",
    "checkout_status_title": "Waiting for checkout",
    "checkout_status_desc": "If you opened this page from Aliolo billing, the payment form should appear automatically.",
    "checkout_payment_support_title": "Payment support",
    "checkout_payment_support_desc": "Web payments are processed by Paddle.com as Merchant of Record.",
    "checkout_billing_title": "Subscription billing",
    "checkout_billing_desc": "Aliolo Premium renews automatically until canceled. You can cancel later through Paddle or your Aliolo account.",
    "checkout_policy_title": "Need policy details?",
    "checkout_policy_desc": "Review pricing, subscription terms, privacy, and refund information before completing your purchase.",

    # Landing Page Metadata & Nav
    "landing_meta_title": "Aliolo | Visual Flashcards, Spaced Repetition, and Smarter Study Workflows",
    "landing_meta_desc": "Aliolo helps learners master languages, science, anatomy, exam prep, and curated subjects with visual flashcards, spaced repetition, and interactive test modes.",
    "landing_nav_features": "Features",
    "landing_nav_how_it_works": "How it works",
    "landing_nav_pricing": "Pricing",
    "landing_nav_login": "Log in",
    "landing_nav_cta": "Create free account",

    # Landing Hero Section
    "landing_hero_eyebrow": "Visual learning platform",
    "landing_hero_h1": "Learn visually. Remember longer.",
    "landing_hero_p": "Turn images, audio, video, and text into structured flashcards. Learn with context, review at the right time, and test what you can truly recall.",
    "landing_hero_btn_primary": "Create free account",
    "landing_hero_btn_secondary": "Log in",
    
    # Hero Highlights
    "landing_hero_proof_1_title": "Visual",
    "landing_hero_proof_1_desc": "Image, audio, and video friendly flashcards for recognition-heavy learning.",
    "landing_hero_proof_2_title": "Adaptive",
    "landing_hero_proof_2_desc": "Spaced repetition and progress tracking to revisit material at the right time.",
    "landing_hero_proof_3_title": "Structured",
    "landing_hero_proof_3_desc": "Pillars, folders, subjects, and collections that scale beyond a simple deck.",
    
    # Hero Preview Caption
    "landing_hero_preview_title": "Recognition before recall",
    "landing_hero_preview_desc": "A real Aliolo lesson using image, text, audio, and guided navigation.",
    "landing_hero_preview_chip": "Learn mode",

    # Features Section Header
    "landing_features_h2": "Everything you need to turn exposure into recall.",
    "landing_features_p": "Build recognition with rich media, keep larger libraries organized, and revisit material before it fades.",

    # Feature Cards
    "landing_feature_1_title": "Learn with more than text",
    "landing_feature_1_desc": "Use images, audio, video, and flexible prompts when the subject depends on recognition and context.",
    "landing_feature_2_title": "Review before it fades",
    "landing_feature_2_desc": "Spaced repetition and progress tracking bring important material back at a useful time.",
    "landing_feature_3_title": "Grow beyond one deck",
    "landing_feature_3_desc": "Organize curated or custom material into pillars, folders, subjects, and collections that stay usable.",

    # Workflow Section Header
    "landing_workflow_h2": "A clear path from \"I should study\" to \"I know this.\"",
    "landing_workflow_p": "One focused workflow keeps the next step obvious without flattening every subject into the same kind of card.",

    # Workflow Steps
    "landing_step_1_title": "Choose the right material",
    "landing_step_1_desc": "Start with a curated subject or build a focused library for an exam, language, profession, or personal goal.",
    "landing_step_2_title": "Learn with context",
    "landing_step_2_desc": "Build recognition through guided cards and available media before asking your memory to work unaided.",
    "landing_step_3_title": "Test real recall",
    "landing_step_3_desc": "Move into focused testing to expose weak spots, reinforce retrieval, and make progress measurable.",

    # Landing Pricing Section
    "landing_pricing_h2": "Start free. Upgrade when you need the full workflow.",
    "landing_pricing_p": "Create an account without payment. Premium adds spaced repetition, creation, testing, autoplay, private organization, and deeper customization.",

    # Pricing Plans
    "landing_plan_weekly_desc": "Good for short-term pushes, quick reviews, or exam-week prep.",
    "landing_plan_weekly_item_1": "Short commitment window",
    "landing_plan_weekly_item_2": "Fast way to try the premium workflow",
    "landing_plan_weekly_item_3": "Renews automatically until canceled",
    "landing_plan_weekly_btn": "View plan details",

    "landing_plan_monthly_desc": "Balanced access for students building a steady learning habit.",
    "landing_plan_monthly_item_1": "Best for regular weekly study",
    "landing_plan_monthly_item_2": "Enough time to organize larger subject libraries",
    "landing_plan_monthly_item_3": "Renews automatically until canceled",
    "landing_plan_monthly_btn": "View plan details",

    "landing_plan_yearly_desc": "Lowest effective monthly cost for learners who want a durable study system.",
    "landing_plan_yearly_item_1": "Ideal for long-term language and professional study",
    "landing_plan_yearly_item_2": "Lower cost over time",
    "landing_plan_yearly_item_3": "Renews automatically until canceled",
    "landing_plan_yearly_btn": "View plan details",

    # Trust Section
    "landing_trust_h2": "Study with clarity. Subscribe with confidence.",
    "landing_trust_p": "Know what is free, what Premium adds, and where to get help before you commit.",
    
    "landing_trust_item_1_title": "Free entry:",
    "landing_trust_item_1_desc": "Create an account and explore available learning material without entering payment details.",
    "landing_trust_item_2_title": "Transparent terms:",
    "landing_trust_item_2_desc": "Pricing, renewal, cancellation, privacy, and refund information are available before checkout.",
    "landing_trust_item_3_title": "Human support:",
    "landing_trust_item_3_desc": "Contact vitalii@nohainc.com when you need help.",

    # Mini FAQ
    "landing_faq_1_q": "Do I need to create every card myself?",
    "landing_faq_1_a": "No. Start with available curated subjects, then create your own material when your goal becomes more specific.",
    "landing_faq_2_q": "Can I use Aliolo for free?",
    "landing_faq_2_a": "Yes. A free account provides an entry point to the library; the pricing page explains which advanced workflows require Premium.",
    "landing_faq_3_q": "Can I cancel a subscription?",
    "landing_faq_3_a": "Yes. Subscriptions can be canceled through the channel where they were purchased, with access normally continuing through the paid period.",

    # Final CTA
    "landing_final_h2": "Ready to make your next study session count?",
    "landing_final_p": "Create a free account, choose a subject, and start learning visually.",
    "landing_final_btn": "Create free account",

    # Footer
    "landing_footer_desc": "Visual flashcards, spaced repetition, flexible subject organization, and focused testing workflows for learners who want structure without friction.",
    "landing_footer_mor": "Merchant of Record:",
    "landing_footer_mor_desc": "Our order process may be conducted by Paddle.com, our online reseller and Merchant of Record for web orders. Paddle handles payment processing, payment-related customer service, and returns for those orders."
}

def translate_google(text: str, target_lang: str) -> str:
    if target_lang == "en":
        return text
    
    # Simple cleanups
    text_to_send = text.strip()
    if not text_to_send:
        return text
        
    url = "https://translate.googleapis.com/translate_a/single"
    params = {
        "client": "gtx",
        "sl": "en",
        "tl": target_lang,
        "dt": "t",
        "q": text_to_send
    }
    encoded_params = urllib.parse.urlencode(params)
    req = urllib.request.Request(f"{url}?{encoded_params}")
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))
            translated = "".join([sentence[0] for sentence in data[0] if sentence[0]])
            # Add back trailing/leading spaces if original text had them
            if text.startswith(" "):
                translated = " " + translated
            if text.endswith(" "):
                translated = translated + " "
            return translated
    except Exception as e:
        print(f"  Warning: Translation failed for language '{target_lang}', text '{text_to_send[:30]}...': {e}")
        return text

def translate_html(html: str, lang: str) -> str:
    if lang == "en":
        return html
    # Split by HTML tags
    tokens = re.split(r'(<[^>]+>)', html)
    translated_tokens = []
    for token in tokens:
        if token.startswith('<') and token.endswith('>'):
            translated_tokens.append(token)
        elif not token.strip():
            translated_tokens.append(token)
        else:
            # Avoid translating standalone punctuation
            if re.match(r'^[✓✕$•\s\d.,:;!?-]+$', token):
                translated_tokens.append(token)
            else:
                translated_text = translate_google(token, lang)
                translated_tokens.append(translated_text)
    return "".join(translated_tokens)

def align_capitalization(en_val: str, target_val: str) -> str:
    if not en_val or not target_val:
        return target_val
    en_first_letter_idx = -1
    for i, c in enumerate(en_val):
        if c.isalpha():
            en_first_letter_idx = i
            break
    if en_first_letter_idx == -1:
        return target_val
    en_char = en_val[en_first_letter_idx]
    is_upper = en_char.isupper()
    target_first_letter_idx = -1
    for i, c in enumerate(target_val):
        if c.isalpha():
            target_first_letter_idx = i
            break
    if target_first_letter_idx == -1:
        return target_val
    target_char = target_val[target_first_letter_idx]
    if is_upper:
        new_char = target_char.upper()
    else:
        new_char = target_char.lower()
    return target_val[:target_first_letter_idx] + new_char + target_val[target_first_letter_idx + 1:]

def main():
    script_dir = Path(__file__).resolve().parent
    # Set api translations directory
    trans_dir = script_dir.parent.parent / "api" / "src" / "translations"
    trans_dir.mkdir(parents=True, exist_ok=True)
    
    translations_map = {}

    for lang in SUPPORTED_LANGUAGES:
        print(f"Translating static pages for language: {lang}...")
        
        nano_file_path = trans_dir / f"{lang}.nano"
        
        # If english, save original
        if lang == "en":
            translated_dict = ENGLISH_CONTENT.copy()
        else:
            translated_dict = {}
            for key, val in ENGLISH_CONTENT.items():
                if key.endswith("_body") or key == "landing_meta_desc" or key == "landing_hero_p":
                    translated_dict[key] = translate_html(val, lang)
                else:
                    translated_val = translate_google(val, lang)
                    translated_dict[key] = align_capitalization(val, translated_val)
                # Sleep a tiny bit to prevent rate limits
                time.sleep(0.08)
        
        # Write nano file
        nano_lines = [".."]
        for key, val in translated_dict.items():
            if "\n" not in val:
                nano_lines.append(f"    {key} {val}")
            else:
                nano_lines.append(f"    {key}|")
                for line in val.split("\n"):
                    nano_lines.append(f"        {line}")
        
        nano_content = "\n".join(nano_lines)
        nano_file_path.write_text(nano_content, encoding="utf-8")
        print(f"  Saved {lang}.nano ({len(nano_content)} bytes)")
        
        # Save raw content to list
        translations_map[lang] = nano_content
        
    # Compile index.ts file containing all translations
    index_file_path = trans_dir / "index.ts"
    
    ts_lines = [
        "// Auto-generated translations module containing all raw Nano Markup maps",
        "export const rawTranslations: Record<string, string> = {"
    ]
    
    for lang, content in translations_map.items():
        # Escape backticks for JS template literal
        escaped_content = content.replace("`", "\\`").replace("${", "\\${")
        ts_lines.append(f"  {lang}: `\n{escaped_content}\n`,\n")
        
    ts_lines.append("};")
    
    index_file_path.write_text("\n".join(ts_lines), encoding="utf-8")
    print(f"\nSuccessfully compiled translations mapping to {index_file_path}")

if __name__ == "__main__":
    main()
