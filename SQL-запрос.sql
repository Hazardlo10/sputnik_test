
SELECT
    scq.checks_number       AS checks_number,
    ss.store_id             AS store_id,
    scq.employees_id        AS employees_id,
    scq.quantity            AS quantity,
    scq.selling_price       AS selling_price,
    scq.checkout_id1        AS checkout_id,
    scq.start_operation_dt  AS start_operation_dt,
    scq.end_operation_dt    AS end_operation_dt
FROM store_checkout_queues AS scq
JOIN store_stores          AS ss
      ON ss.store_uuid = scq.store_uuid
WHERE ss.store_id IN (98451680, 12864064)
ORDER BY ss.store_id, scq.checkout_id1, scq.start_operation_dt;



WITH sel AS (
    SELECT
        ss.store_id                                          AS store_id,
        scq.checkout_id1                                     AS checkout_id,
        scq.checks_number                                    AS checks_number,
        scq.start_operation_dt                               AS start_operation_dt,
        scq.end_operation_dt                                 AS end_operation_dt
    FROM store_checkout_queues AS scq
    JOIN store_stores          AS ss
          ON ss.store_uuid = scq.store_uuid
    WHERE ss.store_id IN (98451680, 12864064)
),
flagged AS (
    SELECT
        s.*,
        DATEDIFF(
            SECOND,
            LAG(s.end_operation_dt) OVER (
                PARTITION BY s.store_id, s.checkout_id
                ORDER BY s.start_operation_dt),
            s.start_operation_dt
        ) AS pause_sec
    FROM sel AS s
),
islands AS (
    SELECT
        f.*,
        CASE WHEN f.pause_sec IS NULL OR f.pause_sec > 60 THEN 1 ELSE 0 END AS is_new_island
    FROM flagged AS f
),
grouped AS (
    SELECT
        i.*,
        SUM(i.is_new_island) OVER (
            PARTITION BY i.store_id, i.checkout_id
            ORDER BY i.start_operation_dt
            ROWS UNBOUNDED PRECEDING) AS island_id
    FROM islands AS i
)
SELECT
    g.store_id,
    g.checkout_id,
    MIN(g.start_operation_dt)                                   AS queue_start,
    MAX(g.end_operation_dt)                                     AS queue_end,
    COUNT(*)                                                    AS checks_in_queue,
    DATEDIFF(SECOND, MIN(g.start_operation_dt),
                     MAX(g.end_operation_dt))                   AS duration_sec
FROM grouped AS g
GROUP BY g.store_id, g.checkout_id, g.island_id
HAVING COUNT(*) >= 2
ORDER BY g.store_id, g.checkout_id, queue_start;
