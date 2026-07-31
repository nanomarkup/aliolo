import { D1Database } from '@cloudflare/workers-types';

export async function generateSitemapXml(db: D1Database, baseUrl: string): Promise<string> {
    try {
        const subjectsStmt = db.prepare(`
            SELECT
                s.id,
                CASE
                    WHEN MAX(c.updated_at) IS NOT NULL
                         AND datetime(MAX(c.updated_at)) > datetime(s.updated_at)
                    THEN MAX(c.updated_at)
                    ELSE s.updated_at
                END AS updated_at
            FROM subjects s
            LEFT JOIN cards c
                ON c.subject_id = s.id
               AND (c.is_public = 1 OR c.is_public = true)
            WHERE s.is_public = 1 OR s.is_public = true
            GROUP BY s.id, s.updated_at
        `);
        const subjectsRes = await subjectsStmt.all<{id: string, updated_at: string | null}>();
        
        const collectionsStmt = db.prepare(`
            SELECT
                c.id,
                CASE
                    WHEN MAX(s.updated_at) IS NOT NULL
                         AND datetime(MAX(s.updated_at)) > datetime(c.updated_at)
                    THEN MAX(s.updated_at)
                    ELSE c.updated_at
                END AS updated_at
            FROM collections c
            LEFT JOIN collection_items ci ON ci.collection_id = c.id
            LEFT JOIN subjects s
                ON s.id = ci.subject_id
               AND (s.is_public = 1 OR s.is_public = true)
            WHERE c.is_public = 1 OR c.is_public = true
            GROUP BY c.id, c.updated_at
        `);
        const collectionsRes = await collectionsStmt.all<{id: string, updated_at: string | null}>();

        let xml = `<?xml version="1.0" encoding="UTF-8"?>\n`;
        xml += `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n`;

        // Static routes
        const staticRoutes = [
            { path: '/', lastmod: '2026-08-01' },
            { path: '/privacy', lastmod: '2026-04-28' },
            { path: '/terms', lastmod: '2026-04-28' },
            { path: '/refund', lastmod: '2026-04-28' },
            { path: '/pricing', lastmod: '2026-04-28' },
        ];

        for (const route of staticRoutes) {
            xml += `  <url>\n`;
            xml += `    <loc>${escapeXml(baseUrl + route.path)}</loc>\n`;
            xml += `    <lastmod>${route.lastmod}</lastmod>\n`;
            xml += `  </url>\n`;
        }

        // Dynamic Subjects
        for (const s of subjectsRes.results) {
            xml += `  <url>\n`;
            xml += `    <loc>${escapeXml(`${baseUrl}/subject/${s.id}`)}</loc>\n`;
            const date = sitemapDate(s.updated_at);
            if (date) xml += `    <lastmod>${date}</lastmod>\n`;
            xml += `  </url>\n`;
        }

        // Dynamic Collections
        for (const c of collectionsRes.results) {
            xml += `  <url>\n`;
            xml += `    <loc>${escapeXml(`${baseUrl}/collection/${c.id}`)}</loc>\n`;
            const date = sitemapDate(c.updated_at);
            if (date) xml += `    <lastmod>${date}</lastmod>\n`;
            xml += `  </url>\n`;
        }

        xml += `</urlset>`;
        return xml;
    } catch (e) {
        console.error('Sitemap Generation error:', e);
        return `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${baseUrl}/</loc></url></urlset>`;
    }
}

function sitemapDate(value: string | null): string | null {
    return value?.match(/^\d{4}-\d{2}-\d{2}/)?.[0] ?? null;
}

function escapeXml(value: string): string {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
}
