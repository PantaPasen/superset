/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

// Enhanced setup for SaaS KPI reporting using built-in charts
// Superset 5.0.0 already includes excellent charts for SaaS metrics:
// - ECharts Funnel (conversion funnels)
// - ECharts Gauge (KPI indicators) 
// - ECharts Waterfall (revenue analysis)
// - ECharts Sankey (flow analysis)
// - ECharts Mixed Timeseries (multi-metric dashboards)
// - Big Number Period-over-Period (KPI trends)
// - ECharts Bubble (customer segmentation)
// - ECharts Heatmap (activity patterns)

// For individual deployments to add custom overrides
export default function setupPluginsExtra() {
  // The built-in charts in MainPreset already provide excellent SaaS KPI capabilities:
  // 
  // Perfect for SaaS KPIs:
  // - Funnel Chart: Trial-to-paid conversion, onboarding flow
  // - Gauge Chart: NPS scores, churn rate, customer satisfaction
  // - Waterfall Chart: Revenue growth breakdown, cohort analysis  
  // - Sankey Chart: Customer journey flows, feature usage flows
  // - Mixed Timeseries: MRR + customer count, ARR + churn overlay
  // - Big Number Period-over-Period: MRR growth %, customer growth %
  // - Bubble Chart: Customer segmentation (size=revenue, x=usage, y=satisfaction)
  // - Heatmap: User activity patterns, support ticket volumes
  // - Treemap: Revenue by customer segments, feature usage distribution
  // - Radar Chart: Customer health scores, product feature comparison
  // - Pivot Table: Detailed KPI breakdown and analysis
  
  // All necessary SaaS KPI charts are available in the MainPreset
  // No additional plugins needed for comprehensive SaaS reporting
}
