using Statistics

# errors
# d is the data, f is the forecast
errors(d, f) = d[end-length(f)+1:end] - f

# forecast bias
# f is the forecast, for the last periods
bias(d, f) = mean(errors(d,f))

# forecast mae
# f is the forecast
mae(d, f) = mean(abs.(errors(d,f)))

# forecast mse
# f is the forecast
mse(d, f) = mean(abs2.(errors(d,f)))

# forecast rmse
# f is the forecast
rmse(d, f) = sqrt(mse(d,f))

#
# outliers, bigger than factor time surronding values
# returns a boolean array
#
outliers(d, factor = 2) = [(i == 1 || d[i] >= factor * d[i-1]) && (i == length(d) || d[i] >= factor * d[i+1])  for (i,v) in enumerate(d)]

#
# exponential smoothing
#
function exponential_smoothing(d;α=0.7,f1=0,outlierfactor = 2,without_outliers = true)
    f = similar(d)
    dno = d
    if without_outliers
        o = outliers(d, outlierfactor)
        dno = [o[i] ? round(Int,(d[max(i-1,1)]+d[min(i+1,length(d))])/2) : v for (i,v) in enumerate(d)]
    end
    f[1] = f1
    for (i,v) in enumerate(dno[1:end-1])
        f[i+1] = round(Int,α * v + (1 - α) * f[i])
    end
    return f
end