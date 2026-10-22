-- Orwickle seed — project categories
INSERT INTO categories (name, slug, sort_order) VALUES
  ('FinTech',              'fintech',         1),
  ('EdTech',               'edtech',          2),
  ('HealthTech',           'healthtech',      3),
  ('E-Commerce',           'e-commerce',      4),
  ('AgriTech',             'agritech',        5),
  ('Logistics',            'logistics',       6),
  ('AI / Machine Learning','ai-ml',           7),
  ('Productivity / SaaS',  'saas',            8),
  ('Social / Community',   'social',          9),
  ('Gaming',               'gaming',         10),
  ('Web Application',      'web-app',        11),
  ('Mobile Application',   'mobile-app',     12),
  ('Other',                'other',          99)
ON CONFLICT (slug) DO NOTHING;
