-- PortfolioOps — Sample BigQuery Analytics Queries
-- Table: `<PROJECT_ID>.portfolio_analytics.visitor_events`
-- Note: All queries filter on the DAY-partitioned `timestamp` column to minimize bytes scanned.

-- 1. Daily visitor summary (last 30 days)
SELECT
  DATE(timestamp) AS visit_date,
  COUNTIF(event_type = 'page_view') AS page_views,
  COUNT(DISTINCT session_id) AS approx_unique_visitors,
  COUNTIF(event_type = 'resume_download') AS resume_downloads
FROM `portfolio_analytics.visitor_events`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY visit_date
ORDER BY visit_date DESC;

-- 2. Top referral domains (last 14 days)
SELECT
  COALESCE(referrer_domain, 'direct') AS referrer_domain,
  COUNT(*) AS events,
  COUNT(DISTINCT session_id) AS approx_unique_visitors
FROM `portfolio_analytics.visitor_events`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)
  AND event_type = 'page_view'
GROUP BY referrer_domain
ORDER BY approx_unique_visitors DESC
LIMIT 20;

-- 3. Device category breakdown (last 30 days)
SELECT
  device_category,
  COUNT(*) AS page_views,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_share
FROM `portfolio_analytics.visitor_events`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND event_type = 'page_view'
GROUP BY device_category
ORDER BY page_views DESC;

-- 4. Hourly traffic anomaly detection (last 24h vs 7-day hourly baseline)
WITH hourly AS (
  SELECT
    TIMESTAMP_TRUNC(timestamp, HOUR) AS hour_bucket,
    COUNT(*) AS views
  FROM `portfolio_analytics.visitor_events`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
    AND event_type = 'page_view'
  GROUP BY hour_bucket
),
baseline AS (
  SELECT
    AVG(views) AS avg_hourly_views,
    STDDEV(views) AS stddev_hourly_views
  FROM hourly
)
SELECT
  h.hour_bucket,
  h.views,
  ROUND(b.avg_hourly_views, 1) AS baseline_avg,
  h.views > (b.avg_hourly_views + 3 * COALESCE(b.stddev_hourly_views, 0)) AS is_anomaly
FROM hourly h
CROSS JOIN baseline b
WHERE h.hour_bucket >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY h.hour_bucket DESC;
