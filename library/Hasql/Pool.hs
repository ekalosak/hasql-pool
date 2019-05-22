module Hasql.Pool
(
  Pool,
  Settings(..),
  acquire,
  release,
  UsageError(..),
  use,
)
where

import Hasql.Pool.Prelude
import qualified Hasql.Connection
import qualified Hasql.Session
import qualified Data.Pool as ResourcePool
import qualified Hasql.Pool.ResourcePool as ResourcePool


-- |
-- A pool of connections to DB.
newtype Pool =
  Pool (ResourcePool.Pool (Either Hasql.Connection.ConnectionError Hasql.Connection.Connection))

-- |
-- Settings of the connection pool. Consist of:
-- 
-- * Pool-size.
-- 
-- * Stripes
-- Number of sub-pools. For more info, see Data.Pool (resource-pool).
-- 
-- * Timeout.   
-- An amount of time for which an unused resource is kept open.
-- The smallest acceptable value is 0.5 seconds.
-- 
-- * Connection settings.
-- 
type Settings =
  (Int, Int, NominalDiffTime, Hasql.Connection.Settings)

-- |
-- Given the pool-size, timeout and connection settings
-- create a connection-pool.
acquire :: Settings -> IO Pool
acquire (size, stripes, timeout, connectionSettings) =
  fmap Pool $
  ResourcePool.createPool acquire release stripes timeout size
  where
    acquire =
      Hasql.Connection.acquire connectionSettings
    release =
      either (const (pure ())) Hasql.Connection.release

-- |
-- Release the connection-pool.
release :: Pool -> IO ()
release (Pool pool) =
  ResourcePool.destroyAllResources pool

-- |
-- A union over the connection establishment error and the session error.
data UsageError =
  ConnectionError Hasql.Connection.ConnectionError |
  SessionError Hasql.Session.QueryError
  deriving (Show, Eq)

-- |
-- Use a connection from the pool to run a session and
-- return the connection to the pool, when finished.
use :: Pool -> Hasql.Session.Session a -> IO (Either UsageError a)
use (Pool pool) session =
  fmap (either (Left . ConnectionError) (either (Left . SessionError) Right)) $
  ResourcePool.withResourceOnEither pool $
  traverse $
  Hasql.Session.run session
