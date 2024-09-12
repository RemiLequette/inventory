
#
# forecast bias
# f is the forceast function
#
function forecast_bias(d, f)
    forecast = f(d)
    bias = mean(d[end-length(forecast)+1:end] - forecast)
    return bias
end
    

#
# exponential smoothing
#
function forecast_exponential_smoothing(y::Vector{T}, alpha::T, h::Int) where T
    n = length(y)
    yhat = similar(y)
    yhat[1] = y[1]
    for i in 2:n
        yhat[i] = alpha * y[i] + (1 - alpha) * yhat[i - 1]
    end
    forecast = similar(y)
    forecast[1:n] = yhat
    for i in n+1:n+h
        forecast[i] = yhat[n]
    end
    return forecast
end