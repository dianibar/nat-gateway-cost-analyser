SELECT 
  account_id,
  srcaddr as nat_private_ip,
  dstaddr,
  'ingress' as flow_direction,
  nat_gateway_id,
  availability_zone,
  ROUND(SUM(bytes) / 1024.0 / 1024.0 / 1024.0, 4) as usage_gb,
  ROUND((SUM(bytes) / 1024.0 / 1024.0 / 1024.0) * 0.045, 4) as cost_usd
FROM "nat_gateway_analysis_vpc_flow_logs"."vpc_flow_logs" vpc
JOIN "nat_gateway_analysis_vpc_flow_logs"."nat_gateway_metadata" nat 
  ON vpc.interface_id = nat.interface_id
WHERE vpc.flow_direction = 'egress'
  AND vpc.srcaddr = nat.private_ip
  AND REGEXP_LIKE(vpc.dstaddr, '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.)')
  AND vpc.year = ?
  AND vpc.month = ?
  AND vpc.day = ?
GROUP BY account_id, dstaddr, srcaddr, nat_gateway_id, availability_zone, flow_direction
ORDER BY usage_gb DESC
LIMIT 30
