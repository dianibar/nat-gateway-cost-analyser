SELECT 
  vpc.account_id,
  vpc.srcaddr,
  'ingress' as flow_direction,
  nat.nat_gateway_id,
  nat.availability_zone,
  ROUND(SUM(vpc.bytes) / 1024.0 / 1024.0 / 1024.0, 4) as usage_gb,
  ROUND((SUM(vpc.bytes) / 1024.0 / 1024.0 / 1024.0) * 0.045, 4) as cost_usd
FROM "nat_gateway_analysis_vpc_flow_logs"."vpc_flow_logs" vpc
JOIN "nat_gateway_analysis_vpc_flow_logs"."nat_gateway_metadata" nat 
  ON vpc.interface_id = nat.interface_id
WHERE vpc.flow_direction = 'egress'
  AND vpc.srcaddr = nat.private_ip
  AND REGEXP_LIKE(vpc.dstaddr, '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.)')
  AND vpc.year = ?
  AND vpc.month = ?
  AND vpc.day = ?
GROUP BY vpc.account_id, vpc.srcaddr, vpc.flow_direction, nat.nat_gateway_id, nat.availability_zone
ORDER BY usage_gb DESC
LIMIT 30
