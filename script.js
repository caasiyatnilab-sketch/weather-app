/**
 * Weather App - JavaScript
 * A beginner-friendly weather application using OpenWeatherMap API
 * 
 * To get a free API key:
 * 1. Go to https://openweathermap.org/ap
 * 2. Sign up for a free account
 * 3. Go to "My API Keys" and copy your key
 * 4. Replace 'YOUR_API_KEEY' below with your actual key
 */

// ===== CONFIGURATION =====
const API_KEY = 'YOUR_API_KEY_HERE'; // Replace with your OpenWeatherMap API key
const BASE_URL = 'https://api.openweathermap.org/data/2.5/weather';

// ===== DOM ELEMENTS =====
const cityInput = document.getElementById('cityInput');
const searchBtn = document.querySelector('button');
const weatherInfo = document.getElementById('weatherInfo');
const errorMessage = document.getElementById('errorMessage');
const loadingSpinner = document.getElementById('loadingSpinner');

// ===== EVENT LISTENERS =====
// Search when button is clicked
searchBtn.addEventListener('click', searchWeather);

// Search when Enter key is pressed
cityInput.addEventListener('keypress', function(event) {
    if (event.key === 'Enter') {
        searchWeather();
    }
});

/**
 * Main function to search for weather data
 * This is an async function - it waits for data to come back before continuing
 */
async function searchWeather() {
    // Get the city name from input
    const city = cityInput.value.trim();
    
    // Validation: Check if city name is empty
    if (!city) {
        showError('Please enter a city name');
        return;
    }
    
    // Show loading state
    showLoading(true);
    hideWeatherInfo();
    hideError();
    
    try {
        // Fetch weather data from API
        const weatherData = await fetchWeather(city);
        
        // Display the weather information
        displayWeather(weatherData);
    } catch (error) {
        // Handle errors (city not found, network issues, etc.)
        showError(error.message);
    } finally {
        // Hide loading spinner regardless of success or failure
        showLoading(false);
    }
}

/**
 * Fetch weather data from OpenWeatherMap API
 * @param {string} city - The city name to search for
 * @returns {Promise} - The weather data
 */
async function fetchWeather(city) {
    // Build the API URL with city name and API key
    const url = `${BASE_URL}?q=${encodeURIComponent(city)}&appid=${API_KEY}&units=metric`;
    
    // Make the API request
    const response = await fetch(url);
    
    // Check if the city was found
    if (!response.ok) {
        if (response.status === 404) {
            throw new Error('City not found. Please check the spelling.');
        } else if (response.status === 401) {
            throw new Error('Invalid API key. Please check your OpenWeatherMap API key.');
        } else {
            throw new Error('Failed to fetch weather data. Please try again.');
        }
    }
    
    // Convert response to JSON format
    const data = await response.json();
    return data;
}

/**
 * Display weather information on the page
 * @param {Object} data - The weather data from API
 */
function displayWeather(data) {
    // ===== EXTRACT DATA =====
    // API returns temperature in Celsius (because we used units=metric)
    const temperature = Math.round(data.main.temp);
    const feelsLike = Math.round(data.main.feels_like);
    const humidity = data.main.humidity;
    const pressure = data.main.pressure;
    const windSpeed = data.wind.speed;
    
    // Weather description (e.g., "partly cloudy")
    const description = data.weather[0].description;
    
    // City name from API (might be formatted differently)
    const cityName = data.name;
    
    // Get weather icon code from API
    const iconCode = data.weather[0].icon;
    const iconUrl = `https://openweathermap.org/img/wn/${iconCode}@2x.png`;
    
    // Get current date
    const date = new Date().toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    
    // ===== UPDATE THE DOM =====
    // Set city name
    document.getElementById('cityName').textContent = cityName;
    document.getElementById('date').textContent = date;
    
    // Set temperature
    document.getElementById('temp').textContent = temperature;
    
    // Set weather description and icon
    document.getElementById('description').textContent = description;
    document.getElementById('weatherIcon').src = iconUrl;
    document.getElementById('weatherIcon').alt = description;
    
    // Set weather details
    document.getElementById('feelsLike').textContent = `${feelsLike}°C`;
    document.getElementById('humidity').textContent = `${humidity}%`;
    document.getElementById('windSpeed').textContent = `${windSpeed} m/s`;
    document.getElementById('pressure').textContent = `${pressure} hPa`;
    
    // Show the weather info section
    hideLoading();
    hideError();
    weatherInfo.classList.remove('hidden');
}

/**
 * Show error message to user
 * @param {string} message - The error message to display
 */
function showError(message) {
    errorMessage.textContent = message;
    errorMessage.classList.remove('hidden');
    weatherInfo.classList.add('hidden');
}

/**
 * Hide error message
 */
function hideError() {
    errorMessage.classList.add('hidden');
}

/**
 * Show or hide loading spinner
 * @param {boolean} isLoading - Whether to show or hide
 */
function showLoading(isLoading) {
    if (isLoading) {
        loadingSpinner.classList.remove('hidden');
    } else {
        loadingSpinner.classList.add('hidden');
    }
}

function hideLoading() {
    loadingSpinner.classList.add('hidden');
}

/**
 * Hide weather info section
 */
function hideWeatherInfo() {
    weatherInfo.classList.add('hidden');
}

// ===== TESTING =====
console.log('Weather App loaded! To test, you\'ll need to:');
console.log('1. Get a free API key from https://openweathermap.org/api');
console.log('2. Replace YOUR_API_KEY_HERE in script.js with your key');