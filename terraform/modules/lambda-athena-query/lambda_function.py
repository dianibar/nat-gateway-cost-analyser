import boto3
import json
import time
from datetime import datetime
import os
import requests
import uuid

athena_client = boto3.client('athena')
s3_client = boto3.client('s3')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event, context):
    """
    Execute Athena queries and send results to DoitHub API
    
    Uses current date (year, month, day) automatically.
    Always executes both public and private IP queries.
    Sends results to DoitHub API in the required format.
    
    Event format (optional - ignored):
    {}
    """
    
    try:
        # Get current date
        today = datetime.now()
        year = "2026"#today.strftime('%Y')
        month = "2"#today.strftime('%m')
        day = "2"#today.strftime('%d')
        
        print(f"\n{'='*80}")
        print(f"Executing Athena Queries for {year}-{month}-{day}")
        print(f"{'='*80}\n")
        
        # Get DoitHub API credentials
        doithub_config = get_doithub_credentials()
        
        # Execute all four queries
        results_public = execute_query_and_print(
            query_type='public',
            year=year,
            month=month,
            day=day
        )
        
        results_private = execute_query_and_print(
            query_type='private',
            year=year,
            month=month,
            day=day
        )
        
        results_ingress_private = execute_query_and_print(
            query_type='ingress_private',
            year=year,
            month=month,
            day=day
        )
        
        results_egress_public = execute_query_and_print(
            query_type='egress_public',
            year=year,
            month=month,
            day=day
        )
        
        # Send results to DoitHub
        print(f"\n{'-'*80}")
        print("Sending results to DoitHub API")
        print(f"{'-'*80}\n")
        
        # Send first batch (queries 1 & 2) - Summary
        print("Batch 1: NAT Gateway usage summary (queries 1 & 2)")
        send_to_doithub(
            doithub_config=doithub_config,
            results=[results_public, results_private],
            date=f'{year}-{month}-{day}',
            provider='NAT Gateway usage summary'
        )
        
        # Send second batch (queries 3 & 4) - Top
        print("\nBatch 2: NAT Gateway usage top (queries 3 & 4)")
        send_to_doithub(
            doithub_config=doithub_config,
            results=[results_ingress_private, results_egress_public],
            date=f'{year}-{month}-{day}',
            provider='Nat Gateway usage top'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'All queries executed and results sent to DoitHub in 2 batches',
                'date': f'{year}-{month}-{day}',
                'batch1': {
                    'provider': 'NAT Gateway usage summary',
                    'publicIPRowCount': results_public['rowCount'],
                    'privateIPRowCount': results_private['rowCount'],
                    'publicIPQueryId': results_public['queryExecutionId'],
                    'privateIPQueryId': results_private['queryExecutionId']
                },
                'batch2': {
                    'provider': 'Nat Gateway usage top',
                    'ingressPrivateIPRowCount': results_ingress_private['rowCount'],
                    'egressPublicIPRowCount': results_egress_public['rowCount'],
                    'ingressPrivateIPQueryId': results_ingress_private['queryExecutionId'],
                    'egressPublicIPQueryId': results_egress_public['queryExecutionId']
                }
            })
        }
    
    except Exception as e:
        print(f"\nError: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def get_doithub_credentials():
    """Retrieve DoitHub API credentials from AWS Secrets Manager"""
    
    try:
        secret_name = os.environ.get('DATAHUB_SECRET_NAME')
        
        if not secret_name:
            raise Exception('DATAHUB_SECRET_NAME environment variable not set')
        
        print(f"Retrieving DoitHub credentials from secret: {secret_name}")
        
        response = secrets_client.get_secret_value(SecretId=secret_name)
        
        if 'SecretString' in response:
            secret = json.loads(response['SecretString'])
            print("✓ DoitHub credentials retrieved successfully")
            return secret
        else:
            raise Exception('Secret does not contain SecretString')
    
    except Exception as e:
        print(f"Error retrieving DoitHub credentials: {str(e)}")
        raise


def send_to_doithub(doithub_config, results, date, provider):
    """Send query results to DoitHub API in the required format"""
    
    try:
        api_url = doithub_config.get('api_url')
        api_key = doithub_config.get('api_key')
        customer_context = doithub_config.get('customer_context')
        
        if not all([api_url, api_key, customer_context]):
            raise Exception('Missing required DoitHub configuration')
        
        # Combine results from all queries in this batch
        all_events_data = []
        
        for result in results:
            if result['data']:
                all_events_data.extend(result['data'])
        
        # Convert results to DoitHub event format
        events = convert_to_doithub_events(all_events_data, results[0]['header'], date, provider)
        
        # Prepare payload
        payload = {
            'events': events
        }
        
        # Prepare headers
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_key}',
            'Accept': 'application/json'
        }
        
        # Add customer context to URL
        url = f"{api_url}?customerContext={customer_context}"
        
        print(f"Provider: {provider}")
        print(f"Sending data to: {api_url}")
        print(f"Number of events: {len(events)}")
        print(f"Payload size: {len(json.dumps(payload))} bytes")
        
        # Send request
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        print(f"Response status: {response.status_code}")
        
        if response.status_code in [200, 201, 202]:
            print("✓ Data sent to DoitHub successfully")
            try:
                response_data = response.json()
                print(f"Response: {json.dumps(response_data, indent=2)[:500]}")
            except:
                print(f"Response: {response.text[:200]}")
        else:
            print(f"⚠ DoitHub API returned status {response.status_code}")
            print(f"Response: {response.text}")
            raise Exception(f"DoitHub API error: {response.status_code} - {response.text}")
    
    except Exception as e:
        print(f"Error sending data to DoitHub: {str(e)}")
        raise


def convert_to_doithub_events(results, header, date, provider):
    """Convert query results to DoitHub event format"""
    
    events = []
    
    # Create a mapping of column names to indices (case-insensitive)
    col_map = {}
    for idx, col_name in enumerate(header):
        col_map[col_name.lower()] = idx
    
    # Get current timestamp in RFC 3339/ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
    current_timestamp = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    # Check if this is a "top" provider (Batch 2) which includes dstaddr
    is_top_provider = 'top' in provider.lower()
    
    for row in results:
        try:
            # Extract values from row using column mapping
            account_id = row[col_map.get('account_id')] if 'account_id' in col_map else ''
            
            # Handle both 'srcaddr' and 'nat_private_ip' column names
            srcaddr = row[col_map.get('srcaddr')] if 'srcaddr' in col_map else ''
            if not srcaddr and 'nat_private_ip' in col_map:
                srcaddr = row[col_map.get('nat_private_ip')]
            
            flow_direction = row[col_map.get('flow_direction')] if 'flow_direction' in col_map else ''
            nat_gateway_id = row[col_map.get('nat_gateway_id')] if 'nat_gateway_id' in col_map else ''
            availability_zone = row[col_map.get('availability_zone')] if 'availability_zone' in col_map else ''
            
            # Get dstaddr if available (for Batch 2)
            dstaddr = row[col_map.get('dstaddr')] if 'dstaddr' in col_map else ''
            
            # Convert numeric fields safely
            try:
                usage_gb = float(row[col_map.get('usage_gb')]) if 'usage_gb' in col_map else 0.0
            except (ValueError, TypeError):
                usage_gb = 0.0
            
            try:
                cost_usd = float(row[col_map.get('cost_usd')]) if 'cost_usd' in col_map else 0.0
            except (ValueError, TypeError):
                cost_usd = 0.0
            
            # Generate UUID for event ID
            event_id = str(uuid.uuid4())
            
            # Build dimensions based on provider type
            dimensions = [
                {
                    'key': 'billing_account_id',
                    'type': 'fixed',
                    'value': account_id
                },
                {
                    'key': 'nat_gateway_id',
                    'type': 'label',
                    'value': nat_gateway_id
                },
                {
                    'key': 'availability_zone',
                    'type': 'label',
                    'value': availability_zone
                },
                {
                    'key': 'flow-direction',
                    'type': 'label',
                    'value': flow_direction
                },
                {
                    'key': 'source_ip',
                    'type': 'label',
                    'value': srcaddr
                }
            ]
            
            # Add dstaddr for Batch 2 (top provider)
            if is_top_provider and dstaddr:
                dimensions.append({
                    'key': 'destination_ip',
                    'type': 'label',
                    'value': dstaddr
                })
            
            # Create event in DoitHub format
            event = {
                'provider': provider,
                'id': event_id,
                'dimensions': dimensions,
                'time': current_timestamp,
                'metrics': [
                    {
                        'value': usage_gb,
                        'type': 'usage_gb'
                    },
                    {
                        'value': cost_usd,
                        'type': 'cost_usd'
                    }
                ]
            }
            
            events.append(event)
            print(f"Created event {event_id} for {nat_gateway_id} at {current_timestamp}")
        
        except Exception as e:
            print(f"Warning: Failed to convert row to event: {str(e)}")
            print(f"Row data: {row}")
            print(f"Column mapping: {col_map}")
            continue
    
    return events


def execute_query_and_print(query_type, year, month, day):
    """Execute a single query and print results"""
    
    try:
        # Get query from environment variables
        if query_type == 'public':
            query = os.environ.get('PUBLIC_IP_QUERY')
            title = "PUBLIC IP TRAFFIC ANALYSIS (EGRESS)"
        elif query_type == 'private':
            query = os.environ.get('PRIVATE_IP_QUERY')
            title = "PRIVATE IP TRAFFIC ANALYSIS (INGRESS)"
        elif query_type == 'ingress_private':
            query = os.environ.get('INGRESS_PRIVATE_IP_QUERY')
            title = "INGRESS PRIVATE IP TRAFFIC ANALYSIS"
        elif query_type == 'egress_public':
            query = os.environ.get('EGRESS_PUBLIC_IP_QUERY')
            title = "EGRESS PUBLIC IP TRAFFIC ANALYSIS"
        else:
            raise Exception(f'Unknown query type: {query_type}')
        
        if not query:
            raise Exception(f'{query_type} query not found in environment')
        
        print(f"\n{'-'*80}")
        print(f"{title}")
        print(f"Date: {year}-{month}-{day}")
        print(f"{'-'*80}\n")
        
        # Execute Athena query
        query_execution_id = execute_athena_query(
            query=query,
            year=year,
            month=month,
            day=day
        )
        
        print(f"Query execution ID: {query_execution_id}")
        
        # Wait for query to complete
        query_status = wait_for_query_completion(query_execution_id)
        
        if query_status != 'SUCCEEDED':
            raise Exception(f'Query failed with status: {query_status}')
        
        # Get query results
        results = get_query_results(query_execution_id)
        
        # Print results
        print_results_table(results)
        
        return {
            'queryExecutionId': query_execution_id,
            'queryType': query_type,
            'rowCount': len(results) - 1,  # Exclude header
            'header': results[0] if results else [],
            'data': results[1:] if results else []
        }
    
    except Exception as e:
        print(f"Error executing {query_type} query: {str(e)}")
        raise


def execute_athena_query(query, year, month, day):
    """Execute Athena query with parameters"""
    
    output_location = f's3://{os.environ.get("ATHENA_RESULTS_BUCKET")}/query-results/'
    workgroup = os.environ.get('ATHENA_WORKGROUP')
    database = os.environ.get('ATHENA_DATABASE')
    
    response = athena_client.start_query_execution(
        QueryString=query,
        QueryExecutionContext={
            'Database': database
        },
        ResultConfiguration={
            'OutputLocation': output_location
        },
        WorkGroup=workgroup,
        ExecutionParameters=[year, month, day]
    )
    
    return response['QueryExecutionId']


def wait_for_query_completion(query_execution_id, max_attempts=60):
    """Wait for Athena query to complete"""
    
    attempt = 0
    while attempt < max_attempts:
        response = athena_client.get_query_execution(
            QueryExecutionId=query_execution_id
        )
        
        status = response['QueryExecution']['Status']['State']
        
        if status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            return status
        
        print(f"Query status: {status} (attempt {attempt + 1}/{max_attempts})")
        time.sleep(2)
        attempt += 1
    
    raise Exception(f"Query did not complete within {max_attempts * 2} seconds")


def get_query_results(query_execution_id):
    """Get results from Athena query"""
    
    results = []
    
    # Get query results from S3
    response = athena_client.get_query_results(
        QueryExecutionId=query_execution_id,
        MaxResults=1000
    )
    
    # Parse results
    for row in response['ResultSet']['Rows']:
        row_data = []
        for field in row['Data']:
            row_data.append(field.get('VarCharValue', ''))
        results.append(row_data)
    
    # Handle pagination if needed
    while 'NextToken' in response:
        response = athena_client.get_query_results(
            QueryExecutionId=query_execution_id,
            MaxResults=1000,
            NextToken=response['NextToken']
        )
        
        for row in response['ResultSet']['Rows']:
            row_data = []
            for field in row['Data']:
                row_data.append(field.get('VarCharValue', ''))
            results.append(row_data)
    
    return results


def print_results_table(results):
    """Print query results as a formatted table with dynamic columns"""
    
    if not results:
        print("No results returned")
        return
    
    # Extract header and data rows
    header = results[0]
    data_rows = results[1:]
    
    # Calculate column widths
    col_widths = []
    for i, col_name in enumerate(header):
        max_width = len(str(col_name))
        for row in data_rows:
            if i < len(row):
                max_width = max(max_width, len(str(row[i])))
        col_widths.append(max_width)
    
    # Determine alignment for each column (right-align for numeric columns)
    col_alignments = []
    for i, col_name in enumerate(header):
        col_name_lower = str(col_name).lower()
        # Right-align numeric columns
        if any(keyword in col_name_lower for keyword in ['bytes', 'gb', 'usd', 'cost', 'usage', 'count', 'packets', 'port']):
            col_alignments.append('right')
        else:
            col_alignments.append('left')
    
    # Print header
    header_parts = []
    for i, h in enumerate(header):
        if col_alignments[i] == 'right':
            header_parts.append(str(h).rjust(col_widths[i]))
        else:
            header_parts.append(str(h).ljust(col_widths[i]))
    header_line = " | ".join(header_parts)
    print(header_line)
    print("-" * len(header_line))
    
    # Print data rows
    for row in data_rows:
        row_parts = []
        for i in range(len(header)):
            value = str(row[i] if i < len(row) else '')
            if col_alignments[i] == 'right':
                row_parts.append(value.rjust(col_widths[i]))
            else:
                row_parts.append(value.ljust(col_widths[i]))
        row_line = " | ".join(row_parts)
        print(row_line)
    
    # Print summary
    print("-" * len(header_line))
    print(f"Total rows: {len(data_rows)}\n")
