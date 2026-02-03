#!/usr/bin/env python3
"""
Script to fetch NAT Gateway information and export to CSV.
Retrieves NAT gateway names, interface IDs, and public IPs.
"""

import boto3
import csv
import sys
from datetime import datetime

def get_nat_gateways(region='us-east-1', output_file='nat_gateways.csv'):
    """
    Fetch NAT Gateway information and save to CSV.
    
    Args:
        region: AWS region (default: us-east-1)
        output_file: Output CSV filename (default: nat_gateways.csv)
    """
    try:
        # Initialize EC2 and S3 clients
        ec2_client = boto3.client('ec2', region_name=region)
        s3_client = boto3.client('s3', region_name=region)
        
        print(f"Fetching NAT Gateways from region: {region}")
        
        # Describe NAT Gateways
        response = ec2_client.describe_nat_gateways()
        nat_gateways = response.get('NatGateways', [])
        
        if not nat_gateways:
            print("No NAT Gateways found in this region.")
            return
        
        # Prepare data for CSV
        nat_gateway_data = []
        
        for nat_gw in nat_gateways:
            # Extract information
            nat_gw_id = nat_gw.get('NatGatewayId', 'N/A')
            nat_gw_name = 'N/A'
            interface_id = nat_gw.get('NatGatewayAddresses', [{}])[0].get('NetworkInterfaceId', 'N/A')
            private_ip = nat_gw.get('NatGatewayAddresses', [{}])[0].get('PrivateIp', 'N/A')
            state = nat_gw.get('State', 'N/A')
            subnet_id = nat_gw.get('SubnetId', 'N/A')
            availability_zone = 'N/A'
            
            # Get the actual availability zone name from the subnet
            if subnet_id != 'N/A':
                try:
                    subnet_response = ec2_client.describe_subnets(SubnetIds=[subnet_id])
                    availability_zone = subnet_response['Subnets'][0].get('AvailabilityZone', 'N/A')
                except:
                    availability_zone = 'N/A'
            
            # Extract name from tags
            tags = nat_gw.get('Tags', [])
            for tag in tags:
                if tag.get('Key') == 'Name':
                    nat_gw_name = tag.get('Value', 'N/A')
                    break
            
            nat_gateway_data.append({
                'NAT_Gateway_ID': nat_gw_id,
                'NAT_Gateway_Name': nat_gw_name,
                'Interface_ID': interface_id,
                'Private_IP': private_ip,
                'Subnet_ID': subnet_id,
                'Availability_Zone': availability_zone,
                'State': state
            })
        
        # Write to CSV
        if nat_gateway_data:
            with open(output_file, 'w', newline='') as csvfile:
                fieldnames = ['NAT_Gateway_ID', 'NAT_Gateway_Name', 'Interface_ID', 'Private_IP', 'Subnet_ID', 'Availability_Zone', 'State']
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                
                writer.writeheader()
                writer.writerows(nat_gateway_data)
            
            print(f"\nSuccessfully exported {len(nat_gateway_data)} NAT Gateway(s) to {output_file}")
            print("\nNAT Gateway Summary:")
            print("-" * 130)
            for nat_gw in nat_gateway_data:
                print(f"Name: {nat_gw['NAT_Gateway_Name']:<40} | Interface: {nat_gw['Interface_ID']:<20} | IP: {nat_gw['Private_IP']:<15} | Subnet: {nat_gw['Subnet_ID']:<20} | AZ: {nat_gw['Availability_Zone']:<12} | State: {nat_gw['State']}")
            print("-" * 130)
        else:
            print("No NAT Gateway data to export.")
    
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

def upload_to_s3(file_path, bucket_name, s3_key=None, region='us-east-1'):
    """
    Upload the CSV file to S3.
    
    Args:
        file_path: Local file path to upload
        bucket_name: S3 bucket name
        s3_key: S3 object key (default: filename)
        region: AWS region (default: us-east-1)
    """
    try:
        s3_client = boto3.client('s3', region_name=region)
        
        if s3_key is None:
            s3_key = file_path.split('/')[-1]
        
        print(f"\nUploading {file_path} to s3://{bucket_name}/{s3_key}")
        s3_client.upload_file(file_path, bucket_name, s3_key)
        print(f"Successfully uploaded to S3!")
        
    except FileNotFoundError:
        print(f"Error: File {file_path} not found.")
    except Exception as e:
        print(f"Error uploading to S3: {e}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Fetch NAT Gateway information and export to CSV')
    parser.add_argument('--region', default='us-east-1', help='AWS region (default: us-east-1)')
    parser.add_argument('--output', default='nat_gateways.csv', help='Output CSV filename (default: nat_gateways.csv)')
    parser.add_argument('--s3-bucket', help='S3 bucket to upload the CSV file')
    parser.add_argument('--s3-key', help='S3 object key (default: filename)')
    
    args = parser.parse_args()
    
    get_nat_gateways(region=args.region, output_file=args.output)
    
    # Upload to S3 if bucket is specified
    if args.s3_bucket:
        upload_to_s3(args.output, args.s3_bucket, args.s3_key, args.region)


def upload_to_s3(file_path, bucket_name, s3_key=None, region='us-east-1'):
    """
    Upload the CSV file to S3.
    
    Args:
        file_path: Local file path to upload
        bucket_name: S3 bucket name
        s3_key: S3 object key (default: filename)
        region: AWS region (default: us-east-1)
    """
    try:
        s3_client = boto3.client('s3', region_name=region)
        
        if s3_key is None:
            s3_key = file_path.split('/')[-1]
        
        print(f"\nUploading {file_path} to s3://{bucket_name}/{s3_key}")
        s3_client.upload_file(file_path, bucket_name, s3_key)
        print(f"Successfully uploaded to S3!")
        
    except FileNotFoundError:
        print(f"Error: File {file_path} not found.")
    except Exception as e:
        print(f"Error uploading to S3: {e}")
