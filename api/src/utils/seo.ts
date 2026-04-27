import { D1Database } from '@cloudflare/workers-types';

export async function generateSeoHtml(db: D1Database, pathname: string, originalHtml: string): Promise<string | null> {
    try {
        let subjectId: string | null = null;
        let isSubject = false;
        
        // Parse outcome-based goals or direct subject pages
        if (pathname.startsWith('/subject/')) {
            subjectId = pathname.split('/')[2];
            isSubject = true;
        } else if (pathname.startsWith('/goals/')) {
            // Outcome-based routing (Item 4)
            // Example: /goals/learn-spanish-medical-terms -> mapping to a specific subject
            // For now, we can match slugified subject names or rely on a new column. 
            // We'll fall back to returning normal HTML if no match.
            const slug = pathname.split('/')[2];
            // Basic matching by name (can be enhanced with a 'slug' column later)
            const stmt = db.prepare("SELECT id FROM subjects WHERE REPLACE(LOWER(name), ' ', '-') = ? LIMIT 1").bind(slug);
            const res = await stmt.first<{id: string}>();
            if (res) {
                subjectId = res.id;
                isSubject = true;
            }
        }
        
        if (!subjectId) return null;

        // Fetch subject info
        const subjectStmt = db.prepare("SELECT name, description FROM subjects WHERE id = ?").bind(subjectId);
        const subject = await subjectStmt.first<{name: string, description: string}>();
        
        if (!subject) return null;

        // Fetch cards
        const cardsStmt = db.prepare("SELECT id, answer, prompt, display_text FROM cards WHERE subject_id = ? LIMIT 50").bind(subjectId);
        const cardsRes = await cardsStmt.all<{id: string, answer: string, prompt: string, display_text: string}>();
        const cards = cardsRes.results;

        // Generate JSON-LD Schema (Item 1: Education Schema)
        const jsonLd = {
            "@context": "https://schema.org",
            "@type": "Quiz",
            "name": `${subject.name} Flashcards`,
            "description": subject.description || `Interactive flashcards for ${subject.name}`,
            "hasPart": cards.map(c => ({
                "@type": "Question",
                "eduQuestionType": "Flashcard",
                "name": c.prompt || "Identify the following:",
                "text": c.prompt || "Identify the following:",
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": c.answer
                }
            }))
        };

        // Generative Engine Optimization Semantic Shell (Item 2)
        let semanticShell = `
            <div id="seo-content" style="display: none;">
                <h1>${escapeHtml(subject.name)} Flashcards</h1>
                <p><strong>Goal:</strong> Master ${escapeHtml(subject.name)}.</p>
                <p>${escapeHtml(subject.description || 'Interactive study material for this topic.')}</p>
                <h2>Flashcard List</h2>
                <dl>
        `;

        for (const c of cards) {
            semanticShell += `
                <dt>${escapeHtml(c.prompt || 'Identify:')}</dt>
                <dd>${escapeHtml(c.answer)}</dd>
            `;
        }
        semanticShell += `</dl></div>`;

        // Inject into original index.html
        let newHtml = originalHtml;
        
        // Inject JSON-LD
        const scriptTag = `<script type="application/ld+json">${JSON.stringify(jsonLd)}</script></head>`;
        newHtml = newHtml.replace('</head>', scriptTag);
        
        // Inject Semantic Shell into Body (Item 5: LCP/INP Skeleton - we can add a visual spinner here too)
        const skeletonUi = `
            <div id="app-loading-skeleton" style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;background:#fff;font-family:sans-serif;">
                <div style="font-size:24px;font-weight:bold;margin-bottom:16px;">Loading ${escapeHtml(subject.name)}...</div>
                <div style="width:300px;height:200px;background:#f0f0f0;border-radius:12px;animation: pulse 1.5s infinite ease-in-out;"></div>
                <style>@keyframes pulse { 0% { opacity: 0.6; } 50% { opacity: 1; } 100% { opacity: 0.6; } }</style>
                ${semanticShell}
            </div>
            <body>
        `;
        newHtml = newHtml.replace('<body>', skeletonUi);

        return newHtml;
    } catch (e) {
        console.error('SEO Generation error:', e);
        return null;
    }
}

function escapeHtml(unsafe: string): string {
    return unsafe
         .replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")
         .replace(/"/g, "&quot;")
         .replace(/'/g, "&#039;");
}