ExUnit.start()

# Define the mock module for PubSub
Mox.defmock(KrakenPrices.PubSubMock, for: KrakenPrices.PubSubBehaviour)
