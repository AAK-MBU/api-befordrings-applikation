""" Helper functions """

import os

import requests

from automation_server_client import AutomationServer
from dotenv import load_dotenv


load_dotenv()
ATS_TOKEN = os.getenv("ATS_TOKEN")
ATS_URL = os.getenv("ATS_URL")


def fetch_workqueue(workqueue_name: str):
    """
    Helper function to fetch the next workqueue in the overall process flow
    """

    headers = {"Authorization": f"Bearer {ATS_TOKEN}"}

    full_url = f"{ATS_URL}/workqueues/by_name/{workqueue_name}"

    response_json = requests.get(full_url, headers=headers, timeout=60).json()
    workqueue_id = response_json.get("id")

    os.environ["ATS_WORKQUEUE_OVERRIDE"] = str(workqueue_id)  # override it
    ats = AutomationServer.from_environment()
    workqueue = ats.workqueue()

    return workqueue
