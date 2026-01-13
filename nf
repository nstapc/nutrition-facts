#!/usr/bin/env node

const https = require('https');
const fs = require('fs');
const path = require('path');
const os = require('os');

const CONFIG_DIR = path.join(os.homedir(), '.config', 'nf');
const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  dim: '\x1b[2m'
};

function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const data = fs.readFileSync(CONFIG_FILE, 'utf8');
      return JSON.parse(data);
    }
  } catch (err) {
    console.error(`${colors.red}Error loading config: ${err.message}${colors.reset}`);
  }
  return null;
}

function saveConfig(apiKey) {
  try {
    if (!fs.existsSync(CONFIG_DIR)) {
      fs.mkdirSync(CONFIG_DIR, { recursive: true });
    }
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiKey }, null, 2));
    console.log(`${colors.green}API key saved to ${CONFIG_FILE}${colors.reset}`);
  } catch (err) {
    console.error(`${colors.red}Error saving config: ${err.message}${colors.reset}`);
  }
}

function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    }).on('error', reject);
  });
}

async function getNutritionData(foodItem, apiKey) {
  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${encodeURIComponent(apiKey)}&query=${encodeURIComponent(foodItem)}&pageSize=1`;
  
  try {
    const data = await httpsGet(url);
    
    if (!data.foods || data.foods.length === 0) {
      return null;
    }

    const food = data.foods[0];
    let protein = 0;
    let carbs = 0;
    let fat = 0;

    if (food.foodNutrients) {
      food.foodNutrients.forEach(nutrient => {
        if (nutrient.nutrientId === 1003 || nutrient.nutrientName === 'Protein') {
          protein = nutrient.value || 0;
        }
        if (nutrient.nutrientId === 1005 || nutrient.nutrientName === 'Carbohydrate, by difference') {
          carbs = nutrient.value || 0;
        }
        if (nutrient.nutrientId === 1004 || nutrient.nutrientName === 'Total lipid (fat)') {
          fat = nutrient.value || 0;
        }
      });
    }

    return {
      name: food.description || foodItem,
      protein: Math.round(protein),
      carbs: Math.round(carbs),
      fat: Math.round(fat)
    };
  } catch (err) {
    throw new Error(`Failed to fetch data: ${err.message}`);
  }
}

function showHelp() {
  console.log(`
${colors.cyan}nf - Nutrition Facts CLI Tool${colors.reset}

${colors.green}USAGE:${colors.reset}
  nf <food_item> [food_item2] [food_item3] ...
  nf --setup <api_key>
  nf --help

${colors.green}EXAMPLES:${colors.reset}
  nf apple
  nf "chicken breast" rice broccoli
  nf --setup YOUR_API_KEY_HERE

${colors.green}SETUP:${colors.reset}
  1. Get a free API key from: https://fdc.nal.usda.gov/api-key-signup.html
  2. Run: nf --setup YOUR_API_KEY_HERE
  3. Start using: nf apple

${colors.dim}Your API key is stored in: ${CONFIG_FILE}${colors.reset}
`);
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    showHelp();
    process.exit(0);
  }

  if (args[0] === '--setup') {
    if (args.length < 2) {
      console.error(`${colors.red}Error: Please provide an API key${colors.reset}`);
      console.log(`Usage: nf --setup YOUR_API_KEY`);
      process.exit(1);
    }
    saveConfig(args[1]);
    process.exit(0);
  }

  const config = loadConfig();
  if (!config || !config.apiKey) {
    console.error(`${colors.red}Error: No API key configured${colors.reset}`);
    console.log(`Run: ${colors.cyan}nf --setup YOUR_API_KEY${colors.reset}`);
    console.log(`Get a free API key at: ${colors.cyan}https://fdc.nal.usda.gov/api-key-signup.html${colors.reset}`);
    process.exit(1);
  }

  const foods = args;
  const results = [];
  let totalProtein = 0;
  let totalCarbs = 0;
  let totalFat = 0;

  for (const food of foods) {
    try {
      const result = await getNutritionData(food, config.apiKey);
      if (result) {
        results.push(result);
        totalProtein += result.protein;
        totalCarbs += result.carbs;
        totalFat += result.fat;
        console.log(`${colors.green}${result.name}:${colors.reset} ${result.protein}g protein, ${result.carbs}g carbs, ${result.fat}g fat`);
      } else {
        console.log(`${colors.red}${food}: Not found${colors.reset}`);
      }
    } catch (err) {
      console.error(`${colors.red}${food}: ${err.message}${colors.reset}`);
    }
  }

  if (results.length > 1) {
    console.log(`${colors.dim}---${colors.reset}`);
    console.log(`${colors.yellow}Total: ${totalProtein}g protein, ${totalCarbs}g carbs, ${totalFat}g fat${colors.reset}`);
  }
}

main().catch(err => {
  console.error(`${colors.red}Error: ${err.message}${colors.reset}`);
  process.exit(1);
});
