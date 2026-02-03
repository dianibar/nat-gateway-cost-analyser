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
        day = "1"#today.strftime('%d')
        
        print(f"\n{'='*80}")
        print(f"Executing Athena Queries for {year}-{month}-{day}")
        print(f"{'='*80}\n")
        
        # Get DoitHub API credentials
        doithub_config = get_doithub_credentials()
        
        # Execute both queries
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
        
        # Send results to DoitHub
        print(f"\n{'-'*80}")
        print("Sending results to DoitHub API")
        print(f"{'-'*80}\n")
        
        send_to_doithub(
            doithub_config=doithub_config,
            public_results=results_public,
            private_results=results_private,
            date=f'{year}-{month}-{day}'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Both queries executed and results sent to DoitHub',
                'date': f'{year}-{month}-{day}',
                'publicIPRowCount': results_public['rowCount'],
                'privateIPRowCount': results_private['rowCount'],
                'publicIPQueryId': results_public['queryExecutionId'],
                'privateIPQueryId': results_private['queryExecutionId']
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


def send_to_doithub(doithub_config, public_results, private_results, date):
    """Send query results to DoitHub API in the required format"""
    
    try:
        api_url = doithub_config.get('api_url')
        api_key = doithub_config.get('api_key')
        customer_context = doithub_config.get('customer_context')
        
        if not all([api_url, api_key, customer_context]):
            raise Exception('Missing required DoitHub configuration')
        
        # Combine results from both queries
        all_results = []
        
        # Add public IP results
        if public_results['data']:
            all_results.extend(public_results['data'])
        
        # Add private IP results
        if private_results['data']:
            all_results.extend(private_results['data'])
        
        # Convert results to DoitHub event format
        events = convert_to_doithub_events(all_results, public_results['header'], date)
        
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


def convert_to_doithub_events(results, header, date):
    """Convert query results to DoitHub event format"""
    
    events = []
    
    # Create a mapping of column names to indices
    col_map = {col.lower(): idx for idx, col in enumerate(header)}
    
    # Get current timestamp in RFC 3339/ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
    current_timestamp = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    for row in results:
        try:
            # Extract values from row
            account_id = row[col_map.get('account_id', 0)] if 'account_id' in col_map else ''
            srcaddr = row[col_map.get('srcaddr', 1)] if 'srcaddr' in col_map else ''
            flow_direction = row[col_map.get('flow_direction', 2)] if 'flow_direction' in col_map else ''
            nat_gateway_id = row[col_map.get('nat_gateway_id', 3)] if 'nat_gateway_id' in col_map else ''
            availability_zone = row[col_map.get('availability_zone', 4)] if 'availability_zone' in col_map else ''
            usage_gb = float(row[col_map.get('usage_gb', 5)]) if 'usage_gb' in col_map else 0.0
            cost_usd = float(row[col_map.get('cost_usd', 6)]) if 'cost_usd' in col_map else 0.0
            
            # Generate UUID for event ID
            event_id = str(uuid.uuid4())
            
            # Create event in DoitHub format
            event = {
                'provider': 'NAT Gateway usage',
                'id': event_id,
                'dimensions': [
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
                ],
                'time': current_timestamp,
                'metrics': [
                    {
                        'usage_gb': usage_gb,
                        'cost_usd': cost_usd
                    }
                ]
            }
            
            events.append(event)
            print(f"Created event {event_id} for {nat_gateway_id} at {current_timestamp}")
        
        except Exception as e:
            print(f"Warning: Failed to convert row to event: {str(e)}")
            continue
    
    return events


def execute_query_and_print(query_type, year, month, day):
    """Execute a single query and print results"""
    
    try:
        # Get query from environment variables
        if query_type == 'public':
            query = os.environ.get('PUBLIC_IP_QUERY')
            title = "PUBLIC IP TRAFFIC ANALYSIS"
        else:
            query = os.environ.get('PRIVATE_IP_QUERY')
            title = "PRIVATE IP TRAFFIC ANALYSIS"
        
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
