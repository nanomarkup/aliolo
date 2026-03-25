ALTER TABLE public.profiles ADD COLUMN main_pillar_id INT DEFAULT 8;

-- Migrate existing colors to IDs if they match (approximate mapping)
UPDATE public.profiles SET main_pillar_id = 1 WHERE main_color = '#D86018' OR main_color = '#607D8B';
UPDATE public.profiles SET main_pillar_id = 2 WHERE main_color = '#C70000' OR main_color = '#F06292';
UPDATE public.profiles SET main_pillar_id = 3 WHERE main_color = '#702082' OR main_color = '#9C27B0';
UPDATE public.profiles SET main_pillar_id = 4 WHERE main_color = '#FFCB05' OR main_color = '#FFC107';
UPDATE public.profiles SET main_pillar_id = 5 WHERE main_color = '#1E6B3B' OR main_color = '#4CAF50';
UPDATE public.profiles SET main_pillar_id = 6 WHERE main_color = '#1D4289' OR main_color = '#3F51B5';
UPDATE public.profiles SET main_pillar_id = 7 WHERE main_color = '#008B8B' OR main_color = '#00BCD4';
UPDATE public.profiles SET main_pillar_id = 8 WHERE main_pillar_id IS NULL OR main_color = '#3D3D3D' OR main_color = '#64748B';

ALTER TABLE public.profiles DROP COLUMN main_color;
