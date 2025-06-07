ExUnit.start()

# Set up Mox for mocking
Mox.defmock(KrakenPrices.PubSubMock, for: KrakenPrices.PubSubBehaviour)
