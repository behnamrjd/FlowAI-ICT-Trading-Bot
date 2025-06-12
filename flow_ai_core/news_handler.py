import requests
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Optional, Any

logger = logging.getLogger(__name__)

class EconomicNewsHandler:
    def __init__(self,
                 news_url: str,
                 monitored_currencies: List[str],
                 monitored_impacts: List[str],
                 cache_ttl_seconds: int = 3600): # Default cache 1 hour
        self.news_url = news_url
        self.monitored_currencies = [c.upper() for c in monitored_currencies]
        self.monitored_impacts = [i.lower() for i in monitored_impacts] # Store impacts as lowercase for case-insensitive compare
        self.cache_ttl_seconds = cache_ttl_seconds

        self.news_events: List[Dict[str, Any]] = []
        self.last_updated_utc: Optional[datetime] = None

        self.fetch_and_process_news()

    def _fetch_raw_news(self) -> Optional[List[Dict]]:
        try:
            logger.info(f"Fetching news from {self.news_url}")
            response = requests.get(self.news_url, timeout=15) # Added timeout
            response.raise_for_status() # Raise HTTPError for bad responses (4xx or 5xx)
            raw_events = response.json()
            if not isinstance(raw_events, list):
                logger.error(f"Fetched news data is not a list as expected. URL: {self.news_url}")
                return None
            logger.info(f"Successfully fetched {len(raw_events)} raw events.")
            return raw_events
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching news from {self.news_url}: {e}")
            return None
        except ValueError as e: # Includes JSONDecodeError
            logger.error(f"Error decoding JSON from {self.news_url}: {e}")
            return None

    def _parse_event(self, raw_event: Dict) -> Optional[Dict[str, Any]]:
        try:
            title = raw_event.get('title')
            country = raw_event.get('country')
            date_str = raw_event.get('date')
            impact = raw_event.get('impact')

            if not all([title, country, date_str, impact]):
                logger.warning(f"Skipping event due to missing essential fields: {raw_event}")
                return None

            # Parse ISO 8601 date string and convert to UTC
            # datetime.fromisoformat handles strings like "2025-06-08T18:45:00-04:00"
            # and correctly interprets the timezone offset.
            event_time_aware = datetime.fromisoformat(date_str)
            event_time_utc = event_time_aware.astimezone(timezone.utc)

            return {
                'title': str(title),
                'country': str(country).upper(),
                'event_time_utc': event_time_utc,
                'impact': str(impact).lower() # Store impact as lowercase
            }
        except ValueError as e: # For fromisoformat errors or other type issues
            logger.warning(f"Error parsing raw event {raw_event}: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error parsing event {raw_event}: {e}")
            return None


    def fetch_and_process_news(self, force_update: bool = False):
        now_utc = datetime.now(timezone.utc)
        if not force_update and self.last_updated_utc:
            if (now_utc - self.last_updated_utc).total_seconds() < self.cache_ttl_seconds:
                logger.info(f"News cache is still fresh. Last updated: {self.last_updated_utc}. Skipping fetch.")
                return

        logger.info("Attempting to fetch and process news...")
        raw_events = self._fetch_raw_news()

        if raw_events is None:
            logger.error("Failed to fetch raw news. News events list will not be updated.")
            # Optionally, consider what to do with stale data: clear it, or keep it with a warning?
            # For now, we'll keep stale data if fetching fails, but last_updated_utc won't change.
            return

        processed_and_filtered_events: List[Dict[str, Any]] = []
        for raw_event in raw_events:
            parsed_event = self._parse_event(raw_event)
            if parsed_event:
                if (parsed_event['country'] in self.monitored_currencies and
                    parsed_event['impact'] in self.monitored_impacts):
                    processed_and_filtered_events.append(parsed_event)

        self.news_events = sorted(processed_and_filtered_events, key=lambda x: x['event_time_utc'])
        self.last_updated_utc = now_utc # Set update time only on successful fetch and process

        logger.info(f"Successfully processed and filtered news. Loaded {len(self.news_events)} relevant events. Last updated: {self.last_updated_utc}")

    def get_upcoming_relevant_events(self,
                                     minutes_before_event_start: int,
                                     minutes_after_event_start: int) -> List[Dict[str, Any]]:
        """
        Gets relevant news events that are active or upcoming.
        An event is considered 'active' from 'minutes_before_event_start' before its time
        until 'minutes_after_event_start' after its time.
        """
        # Ensure news is reasonably fresh, otherwise try to update it.
        # This threshold can be adjusted, e.g., if cache_ttl_seconds is very long.
        if not self.last_updated_utc or \
           (datetime.now(timezone.utc) - self.last_updated_utc).total_seconds() > self.cache_ttl_seconds / 2: # e.g. if older than half TTL
            logger.info("News data might be stale, attempting a refresh before getting upcoming events.")
            self.fetch_and_process_news(force_update=False) # Respect cache TTL but try if very old

        if not self.news_events:
            logger.info("No news events loaded to check for upcoming relevant events.")
            return []

        relevant_now_events = []
        now_utc = datetime.now(timezone.utc)

        # Define the window for checking "active" news
        # An event is active if current time is between (event_time - before_minutes) and (event_time + after_minutes)

        for event in self.news_events:
            event_time = event['event_time_utc']

            # Time window for this event to be considered "active"
            window_start = event_time - timedelta(minutes=minutes_before_event_start)
            window_end = event_time + timedelta(minutes=minutes_after_event_start)

            if window_start <= now_utc <= window_end:
                relevant_now_events.append(event)
            # Optimization: if events are sorted, and current event is far in future, can break
            # elif event_time > now_utc + timedelta(minutes=minutes_after_event_start):
            # This optimization is only valid if minutes_before_event_start is always positive or zero.
            # For simplicity, iterate all if the list is not excessively long.
            # If list is very long and sorted, more efficient filtering can be done.

        if relevant_now_events:
            logger.info(f"Found {len(relevant_now_events)} relevant news events active around current time.")
        else:
            logger.debug("No relevant news events active around current time.")

        return relevant_now_events

if __name__ == '__main__':
    # Example Usage (for testing the module directly)
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    TEST_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
    CURRENCIES = ["USD", "EUR"]
    IMPACTS = ["High", "Medium"] # Will be converted to lowercase internally
    CACHE_TTL = 60 # 1 minute for testing

    handler = EconomicNewsHandler(TEST_URL, CURRENCIES, IMPACTS, CACHE_TTL)

    logger.info(f"Initial load: {len(handler.news_events)} events.")

    # Test get_upcoming_relevant_events
    # To make this test effective, you might need to manually adjust your system clock
    # or have known events in the feed around the current time.
    # For this example, let's assume a wide window to catch something.
    minutes_before = 60
    minutes_after = 120

    upcoming = handler.get_upcoming_relevant_events(minutes_before, minutes_after)
    if upcoming:
        logger.info(f"Found {len(upcoming)} upcoming/active events in the next ~2 hours (considering +/- window):")
        for event in upcoming:
            logger.info(f"  - {event['event_time_utc']} (UTC) | {event['country']} | {event['impact'].upper()} | {event['title']}")
    else:
        logger.info(f"No upcoming/active events found in the next ~2 hours (considering +/- window).")

    # Test caching - should say "News cache is still fresh" if called within CACHE_TTL
    import time
    logger.info("Waiting for 10 seconds and trying to fetch again (should use cache)...")
    time.sleep(10)
    handler.fetch_and_process_news()

    logger.info(f"Waiting for {CACHE_TTL + 5} seconds to bypass cache...")
    time.sleep(CACHE_TTL + 5)
    handler.fetch_and_process_news(force_update=False) # Should now re-fetch
    logger.info(f"After cache expiry: {len(handler.news_events)} events.")
