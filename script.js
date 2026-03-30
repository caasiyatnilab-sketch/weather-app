/**
 * Weather App — Uses wttr.in (free, no API key needed)
 * Fetches current weather + 5-day forecast
 */

const cityInput = document.getElementById("city");
const currentEl = document.getElementById("current");
const forecastEl = document.getElementById("forecast");

async function load() {
  const city = cityInput.value.trim();
  if (!city) return;

  currentEl.innerHTML = '<p style="color:#999">Loading...</p>';
  forecastEl.innerHTML = "";

  try {
    const res = await fetch(`https://wttr.in/${encodeURIComponent(city)}?format=j1`);
    if (!res.ok) throw new Error("City not found");
    const data = await res.json();

    const c = data.current_condition[0];
    const desc = c.weatherDesc[0].value;

    currentEl.innerHTML = `
      <div class="temp">${c.temp_C}°C</div>
      <p class="desc">${desc}</p>
      <div class="details">
        <div class="detail">
          <div class="label">Feels Like</div>
          <div class="value">${c.FeelsLikeC}°C</div>
        </div>
        <div class="detail">
          <div class="label">Humidity</div>
          <div class="value">${c.humidity}%</div>
        </div>
        <div class="detail">
          <div class="label">Wind</div>
          <div class="value">${c.windspeedKmph} km/h</div>
        </div>
        <div class="detail">
          <div class="label">Pressure</div>
          <div class="value">${c.pressure} hPa</div>
        </div>
      </div>
    `;

    forecastEl.innerHTML = data.weather
      .slice(0, 5)
      .map(
        (w) => `
        <div class="day">
          <div class="date">${w.date}</div>
          <div class="range">${w.mintempC}° – ${w.maxtempC}°C</div>
        </div>
      `
      )
      .join("");
  } catch (e) {
    currentEl.innerHTML = `<p style="color:red">Could not load weather for "${city}"</p>`;
  }
}

// Search on button click
document.querySelector("button").addEventListener("click", load);

// Search on Enter
cityInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter") load();
});

// Load default city on page load
load();
