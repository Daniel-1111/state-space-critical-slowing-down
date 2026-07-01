# 1. Install 'remotes' package if not already installed
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

# 2. Install the 'emaph' package directly from the author's GitHub repository
remotes::install_github("jruwaard/emaph")

# 3. Load the package and the Critical Slowing Down (CSD) dataset
library(emaph)
data("csd")

# 4. Inspect the structure and the first rows of the dataset
head(csd)
View(csd)

# Load tidyverse library for data manipulation
library(dplyr)

# Focus on mood_down since it has excellent variance and distribution
time_series_data <- csd %>%
  mutate(time_index = (dayno - 1) * 10 + beepno) %>%
  select(time_index, dayno, beepno, mood_down)

# Verify the final dataset for modeling
head(time_series_data)

# Load ggplot2 for visualization
library(ggplot2)

# Plot the time series of mood_down
ggplot(time_series_data, aes(x = time_index, y = mood_down)) +
  geom_line(color = "darkblue", alpha = 0.5) +
  geom_point(color = "darkblue", size = 0.5) +
  theme_minimal() +
  labs(title = "Patient's Mood Down Over Time", x = "Time Index (Beeps)", y = "Mood Down Score")

# Save the last plotted graph into your project structures
ggsave("mood_down_time_series.png", width = 10, height = 6, dpi = 300)

if (!requireNamespace("bssm", quietly = TRUE)) {
  install.packages("bssm")
}
library(bssm)

#Set up the Local Linear Trend model specification
# sd_y: prior for measurement noise (sigma_epsilon)
# sd_level: prior for level shock (sigma_eta_1)
# sd_slope: prior for trend/slope shock (sigma_eta_2)

# Convert the column explicitly into a pure numeric vector to clear attributes
mood_vector <- as.numeric(time_series_data$mood_down)

model_spec <- bsm_lg(
  y = mood_vector,
  sd_y = halfnormal(init = 1, sd = 5),
  sd_level = halfnormal(init = 0.1, sd = 1),
  sd_slope = halfnormal(init = 0.01, sd = 1)
)

# Run the MCMC sampler
set.seed(42)
mcmc_results <- run_mcmc(model_spec, iter = 2000, burnin = 1000)

# Print parameter estimates
print(mcmc_results)

#  Extract the latent states matrix from the MCMC results
# alpha dimensions are: [Time points, State components, MCMC Iterations]
# Component 1 is 'level', Component 2 is 'slope'
latent_levels <- mcmc_results$alpha[, 1, ]

#  Calculate the mean latent level for each time point across MCMC iterations
mean_latent_level <- rowMeans(latent_levels)

# Trim the last point to match the length of the original data (1476)
mean_latent_level_trimmed <- mean_latent_level[1:1476]

#  Combine into a data frame safely
plot_data <- data.frame(
  time_index = 1:1476,
  observed = as.numeric(time_series_data$mood_down),
  latent = mean_latent_level_trimmed
)

#  Plot Observed vs. Latent State using ggplot2
ggplot(plot_data, aes(x = time_index)) +
  geom_point(aes(y = observed), color = "steelblue", alpha = 0.5, size = 1.2) +
  geom_line(aes(y = latent), color = "darkred", linewidth = 0.8) +
  theme_minimal() +
  labs(
    title = "State-Space Decomposition of Emotional Dynamics",
    subtitle = "Observed Scores (Points) vs. Estimated Latent Mood Level (Red Line)",
    x = "Time Index (Beeps)",
    y = "Mood Down Score"
  )

ggsave("mood_down_latent_filter.png", width = 10, height = 6, dpi = 300)

# Open a high-resolution png device
png("figures/mcmc_diagnostics.png", width = 10, height = 6, units = "in", res = 300)

# Draw the plot into the device
plot(mcmc_results, what = "theta")

# Close and save the file
dev.off()


#Part 2: dividing the data set to assess "resilience" ------------------------


# Convert the full series to numeric just to be safe
full_series <- as.numeric(time_series_data$mood_down)

# Phase 1: First half of the study (Stable Period)
phase1_vector <- full_series[1:750]

# Phase 2: Second half (Pre-transition period)
phase2_vector <- full_series[751:1476]

# 1. Define a custom State-Space Model for an AR(1) process + measurement noise
# we specify the dynamics where the latent state multiplies by a coefficient 'rho' (our T)
# For phase 1:
model_phase1 <- ar1_lg(
  y = phase1_vector,
  rho = uniform(init = 0.3, min = -1, max =1), # Prior for "spring" force T
  mu = normal(init = 4, mean = 4, sd = 2), # latent baseline mean
  sigma = halfnormal(init = 0.2, sd = 1), # Process noise (sd_level)
  sd_y = halfnormal(init = 0.5, sd = 1) # measurement noise (sd_y)

)

# 2. Run MCMC for Phase 1:
set.seed(42)
mcmc_phase1 <- run_mcmc(model_phase1, iter = 3000, burnin = 1500)

# 3. Check results for Phase 1:
print(mcmc_phase1)


# For phase 2:
model_phase2 <- ar1_lg(
  y = phase2_vector,
  rho = uniform(init = 0.3, min = -1, max = 1), 
  mu = normal(init = 4, mean = 4, sd = 2),       
  sigma = halfnormal(init = 0.2, sd = 1),       
  sd_y = halfnormal(init = 0.5, sd = 1)         
)

# Run MCMC for Phase 2
set.seed(42)
mcmc_phase2 <- run_mcmc(model_phase2, iter = 3000, burnin = 1500)

# Check the results for Phase 2
print(mcmc_phase2)




















