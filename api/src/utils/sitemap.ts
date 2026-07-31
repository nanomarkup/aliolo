import { D1Database } from '@cloudflare/workers-types';

export async function generateSitemapXml(db: D1Database, baseUrl: string): Promise<string> {
    try {
        const subjectsStmt = db.prepare("SELECT id, updated_at FROM subjects WHERE is_public = 1 OR is_public = true");
        const subjectsRes = await subjectsStmt.all<{id: string, updated_at: string}>();
        
        const collectionsStmt = db.prepare("SELECT id, updated_at FROM collections WHERE is_public = 1 OR is_public = true");
        const collectionsRes = await collectionsStmt.all<{id: string, updated_at: string}>();

        let xml = `<?xml version="1.0" encoding="UTF-8"?>\n`;
        xml += `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n`;

        // Static routes
        const staticRoutes = [
            { path: '/', freq: 'daily', priority: '1.0' },
            { path: '/privacy', freq: 'monthly', priority: '0.5' },
            { path: '/terms', freq: 'monthly', priority: '0.5' },
            { path: '/refund', freq: 'monthly', priority: '0.5' },
            { path: '/pricing', freq: 'weekly', priority: '0.8' },
        ];

        for (const route of staticRoutes) {
            xml += `  <url>\n`;
            xml += `    <loc>${baseUrl}${route.path}</loc>\n`;
            xml += `    <changefreq>${route.freq}</changefreq>\n`;
            xml += `    <priority>${route.priority}</priority>\n`;
            xml += `  </url>\n`;
        }

        // Dynamic Subjects
        for (const s of subjectsRes.results) {
            const date = s.updated_at ? s.updated_at.split(' ')[0] : new Date().toISOString().split('T')[0];
            xml += `  <url>\n`;
            xml += `    <loc>${baseUrl}/subject/${s.id}</loc>\n`;
            xml += `    <lastmod>${date}</lastmod>\n`;
            xml += `    <changefreq>weekly</changefreq>\n`;
            xml += `    <priority>0.9</priority>\n`;
            xml += `  </url>\n`;
        }

        // Dynamic Collections
        for (const c of collectionsRes.results) {
            const date = c.updated_at ? c.updated_at.split(' ')[0] : new Date().toISOString().split('T')[0];
            xml += `  <url>\n`;
            xml += `    <loc>${baseUrl}/collection/${c.id}</loc>\n`;
            xml += `    <lastmod>${date}</lastmod>\n`;
            xml += `    <changefreq>weekly</changefreq>\n`;
            xml += `    <priority>0.8</priority>\n`;
            xml += `  </url>\n`;
        }

        xml += `</urlset>`;
        return xml;
    } catch (e) {
        console.error('Sitemap Generation error:', e);
        return `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${baseUrl}/</loc></url></urlset>`;
    }
}
