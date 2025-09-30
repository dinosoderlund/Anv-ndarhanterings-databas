import os
from dotenv import load_dotenv
from azure.storage.blob import BlobServiceClient

load_dotenv()

def upload_to_blob(local_file, container="user-data", blob_name="login_attempts.csv"):
    conn_str = os.getenv("AZURE_STORAGE_CONNECTION_STRING") # get from .env
    blob_service = BlobServiceClient.from_connection_string(conn_str)
    blob_client = blob_service.get_blob_client(container=container, blob=blob_name)

    with open(local_file, "rb") as data:
        blob_client.upload_blob(data, overwrite=True)


    print(f"File uploaded to Azure blob {container}/{blob_name}")
if __name__ == "__main__":
    upload_to_blob("login_attempts.csv")
