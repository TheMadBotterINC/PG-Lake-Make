CREATE OR REPLACE TABLE mro_events AS
SELECT
  1000 + row_number() OVER () AS event_id,
  ('N' || lpad(cast(100 + (random()*899)::int as varchar), 3, '0')) AS tail_number,
  date '2025-01-01' + (random()*180)::int AS event_date,
  ['A-CHECK','B-CHECK','C-CHECK','UNSCHEDULED','AOG'][(random()*4)::int+1] AS event_type,
  ['ATL','TPA','JFK','DFW','LHR'][(random()*4)::int+1] AS station,
  ['HYDRAULIC_LEAK','BRAKE_WEAR','AVIONICS_FAULT','CORROSION','ENGINE_OIL'][(random()*4)::int+1] AS fault_code,
  round(1 + random()*48, 1) AS downtime_hours,
  round(500 + random()*150000, 2) AS cost_usd
FROM range(50000);

COPY (SELECT * FROM mro_events)
TO 's3://opdi/flight_list/mro_events.parquet' (FORMAT PARQUET);
