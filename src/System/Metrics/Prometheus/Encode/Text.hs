{-# LANGUAGE OverloadedStrings #-}

module System.Metrics.Prometheus.Encode.Text
       ( encodeMetrics
       ) where

import           Data.ByteString.Builder                         (Builder, toLazyByteString)
import           Data.ByteString.Lazy                            (ByteString)
import           Data.Function                                   (on)
import           Data.List                                       (groupBy,
                                                                  intersperse)
import qualified Data.Map                                        as Map
import           Data.Monoid                                     ((<>))
import           Network.HTTP.Client                             (Request, RequestBody (..),
                                                                  requestBody,
                                                                  requestHeaders)

import           System.Metrics.Prometheus.Encode.Text.Histogram (encodeHistogram)
import           System.Metrics.Prometheus.Encode.Text.MetricId  (encodeDouble,
                                                                  encodeHeader,
                                                                  encodeInt,
                                                                  encodeMetricId,
                                                                  newline,
                                                                  space)
import           System.Metrics.Prometheus.Metric                (MetricSample (..),
                                                                  metricSample)
import           System.Metrics.Prometheus.Metric.Counter        (CounterSample (..))
import           System.Metrics.Prometheus.Metric.Gauge          (GaugeSample (..))
import           System.Metrics.Prometheus.MetricId              (MetricId (..))
import           System.Metrics.Prometheus.Registry              (RegistrySample (..))


metricsRequest :: RegistrySample -> Request -> Request
metricsRequest s req = req
    { requestBody    = RequestBodyLBS . toLazyByteString $ encodeMetrics s
    , requestHeaders = contentType : requestHeaders req
    }
  where contentType = ("Content-Type", "text/plain; version=0.0.4")


encodeMetrics :: RegistrySample -> Builder
encodeMetrics = (<> newline) . mconcat . intersperse newline . map encodeMetricGroup
    . groupByName . Map.toList . unRegistrySample
  where groupByName = groupBy ((==) `on` (name . fst))


encodeMetricGroup :: [(MetricId, MetricSample)] -> Builder
encodeMetricGroup group = encodeHeader mid sample <> newline
    <> mconcat (intersperse newline $ map encodeMetric group)
  where
    (mid, sample) = head group


encodeMetric :: (MetricId, MetricSample) -> Builder
encodeMetric (mid, sample) = metricSample (encodeCounter mid) (encodeGauge mid)
    (encodeHistogram mid) (encodeSummary mid) sample
  where
    encodeSummary = undefined


encodeCounter :: MetricId -> CounterSample -> Builder
encodeCounter mid counter = encodeMetricId mid <> space <> encodeInt (unCounterSample counter)


encodeGauge :: MetricId -> GaugeSample -> Builder
encodeGauge mid gauge = encodeMetricId mid <> space <> encodeDouble (unGaugeSample gauge)
