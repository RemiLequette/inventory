using LinearRegression
using Statistics

# mobile average
ma(df,i,window = 12) = [t <= window ? df[t,i] : round(Int,mean(df[t-window:t-1,i])) for t in eachindex(df[:,i])]


# linear regression (trend)
lr(df,i) = coef(linregress(collect(1:length(df[!,i])),df[!,i]))
