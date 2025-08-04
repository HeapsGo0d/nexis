#!/usr/bin/env python3
"""
Test script for improved error handling in nexis_downloader.py
"""

import sys
import os
import tempfile
from pathlib import Path

# Add the scripts directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from nexis_downloader import NexisDownloader

def test_checksum_verification():
    """Test the improved _verify_checksum method"""
    print("Testing checksum verification error handling...")
    
    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        # Monkey patch the download_tmp_dir to use our temp directory
        downloader = NexisDownloader(debug_mode=True)
        downloader.download_tmp_dir = Path(temp_dir)
    
        # Test 1: Non-existent file
        print("\n1. Testing non-existent file:")
        non_existent_file = Path("/tmp/non_existent_file.txt")
        result = downloader._verify_checksum(non_existent_file, "dummy_hash")
        assert result == False, "Should return False for non-existent file"
        
        # Test 2: Empty hash
        print("\n2. Testing empty hash:")
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmp_file:
            tmp_file.write("test content")
            tmp_file_path = Path(tmp_file.name)
        
        try:
            result = downloader._verify_checksum(tmp_file_path, "")
            assert result == False, "Should return False for empty hash"
            
            result = downloader._verify_checksum(tmp_file_path, None)
            assert result == False, "Should return False for None hash"
        finally:
            tmp_file_path.unlink(missing_ok=True)
        
        # Test 3: Valid checksum verification
        print("\n3. Testing valid checksum:")
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmp_file:
            tmp_file.write("test content")
            tmp_file_path = Path(tmp_file.name)
        
        try:
            # Calculate actual hash for the test file
            import subprocess
            result = subprocess.run(['sha256sum', str(tmp_file_path)],
                                  capture_output=True, text=True, check=True)
            actual_hash = result.stdout.split()[0].lower()
            
            # Test with correct hash
            result = downloader._verify_checksum(tmp_file_path, actual_hash)
            assert result == True, "Should return True for correct hash"
            
            # Test with incorrect hash
            wrong_hash = "0" * 64  # 64 zeros
            result = downloader._verify_checksum(tmp_file_path, wrong_hash)
            assert result == False, "Should return False for incorrect hash"
            
        finally:
            tmp_file_path.unlink(missing_ok=True)
        
        print("✅ All checksum verification tests passed!")

def test_error_message_formatting():
    """Test that error messages are properly formatted"""
    print("\nTesting error message formatting...")
    
    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        # Monkey patch the download_tmp_dir to use our temp directory
        downloader = NexisDownloader(debug_mode=True)
        downloader.download_tmp_dir = Path(temp_dir)
        
        # Capture log output by redirecting stdout
        import io
        import contextlib
        
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            # Test non-existent file error
            non_existent_file = Path("/tmp/non_existent_file.txt")
            downloader._verify_checksum(non_existent_file, "dummy_hash")
        
        output = f.getvalue()
        assert "CHECKSUM ERROR" in output, "Should contain 'CHECKSUM ERROR' in output"
        assert "File does not exist" in output, "Should contain file existence error message"
        
        print("✅ Error message formatting test passed!")

if __name__ == "__main__":
    print("Running error handling tests for nexis_downloader.py")
    print("=" * 60)
    
    try:
        test_checksum_verification()
        test_error_message_formatting()
        
        print("\n" + "=" * 60)
        print("🎉 All tests passed! Error handling improvements are working correctly.")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        sys.exit(1)