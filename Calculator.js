function formatNumber(value) {
  if (!isFinite(value)) return ""
  if (Math.abs(value) < 1e-12) value = 0
  return String(Number(value.toPrecision(8)))
}

function arithmetic(input) {
  var expression = String(input || "").replace(/\s+/g, "")
  if (!expression || !/[+\-*/^()]/.test(expression) || !/^[0-9eE.+\-*/^()]+$/.test(expression)) return null

  var tokens = expression.match(/(?:\d+(?:\.\d*)?|\.\d+)(?:e[+\-]?\d+)?|[+\-*/^()]/gi) || []
  if (tokens.join("").toLowerCase() !== expression.toLowerCase()) return null
  var index = 0

  function primary() {
    var token = tokens[index++]
    if (token === "(") {
      var value = addSub()
      if (tokens[index++] !== ")") throw new Error("Missing closing parenthesis")
      return value
    }
    var number = Number(token)
    if (token === undefined || !isFinite(number)) throw new Error("Expected a number")
    return number
  }

  function power() {
    var value = primary()
    if (tokens[index] === "^") {
      index++
      value = Math.pow(value, unary())
    }
    return value
  }

  function unary() {
    if (tokens[index] === "+") { index++; return unary() }
    if (tokens[index] === "-") { index++; return -unary() }
    return power()
  }

  function multiplyDivide() {
    var value = unary()
    while (tokens[index] === "*" || tokens[index] === "/") {
      var operator = tokens[index++]
      var next = unary()
      if (operator === "/" && next === 0) throw new Error("Division by zero")
      value = operator === "*" ? value * next : value / next
    }
    return value
  }

  function addSub() {
    var value = multiplyDivide()
    while (tokens[index] === "+" || tokens[index] === "-") {
      var operator = tokens[index++]
      var next = multiplyDivide()
      value = operator === "+" ? value + next : value - next
    }
    return value
  }

  try {
    var result = addSub()
    if (index !== tokens.length || !isFinite(result)) return null
    return { kind: "calculation", value: formatNumber(result), copyText: formatNumber(result) }
  } catch (e) {
    return null
  }
}

var units = {
  mm: { dimension: "length", factor: 0.001 }, millimeter: { dimension: "length", factor: 0.001 }, millimeters: { dimension: "length", factor: 0.001 },
  cm: { dimension: "length", factor: 0.01 }, centimeter: { dimension: "length", factor: 0.01 }, centimeters: { dimension: "length", factor: 0.01 },
  m: { dimension: "length", factor: 1 }, meter: { dimension: "length", factor: 1 }, meters: { dimension: "length", factor: 1 }, metre: { dimension: "length", factor: 1 }, metres: { dimension: "length", factor: 1 },
  km: { dimension: "length", factor: 1000 }, kilometer: { dimension: "length", factor: 1000 }, kilometers: { dimension: "length", factor: 1000 }, kilometre: { dimension: "length", factor: 1000 }, kilometres: { dimension: "length", factor: 1000 },
  in: { dimension: "length", factor: 0.0254 }, inch: { dimension: "length", factor: 0.0254 }, inches: { dimension: "length", factor: 0.0254 },
  ft: { dimension: "length", factor: 0.3048 }, foot: { dimension: "length", factor: 0.3048 }, feet: { dimension: "length", factor: 0.3048 },
  yd: { dimension: "length", factor: 0.9144 }, yard: { dimension: "length", factor: 0.9144 }, yards: { dimension: "length", factor: 0.9144 },
  mi: { dimension: "length", factor: 1609.344 }, mile: { dimension: "length", factor: 1609.344 }, miles: { dimension: "length", factor: 1609.344 },
  mg: { dimension: "mass", factor: 0.001 }, g: { dimension: "mass", factor: 1 }, gram: { dimension: "mass", factor: 1 }, grams: { dimension: "mass", factor: 1 },
  kg: { dimension: "mass", factor: 1000 }, kilogram: { dimension: "mass", factor: 1000 }, kilograms: { dimension: "mass", factor: 1000 },
  oz: { dimension: "mass", factor: 28.349523125 }, ounce: { dimension: "mass", factor: 28.349523125 }, ounces: { dimension: "mass", factor: 28.349523125 },
  lb: { dimension: "mass", factor: 453.59237 }, lbs: { dimension: "mass", factor: 453.59237 }, pound: { dimension: "mass", factor: 453.59237 }, pounds: { dimension: "mass", factor: 453.59237 },
  ml: { dimension: "volume", factor: 0.001 }, milliliter: { dimension: "volume", factor: 0.001 }, milliliters: { dimension: "volume", factor: 0.001 },
  l: { dimension: "volume", factor: 1 }, liter: { dimension: "volume", factor: 1 }, liters: { dimension: "volume", factor: 1 }, litre: { dimension: "volume", factor: 1 }, litres: { dimension: "volume", factor: 1 },
  cup: { dimension: "volume", factor: 0.2365882365 }, cups: { dimension: "volume", factor: 0.2365882365 },
  gal: { dimension: "volume", factor: 3.785411784 }, gallon: { dimension: "volume", factor: 3.785411784 }, gallons: { dimension: "volume", factor: 3.785411784 },
  ms: { dimension: "time", factor: 0.001 }, millisecond: { dimension: "time", factor: 0.001 }, milliseconds: { dimension: "time", factor: 0.001 },
  s: { dimension: "time", factor: 1 }, sec: { dimension: "time", factor: 1 }, second: { dimension: "time", factor: 1 }, seconds: { dimension: "time", factor: 1 },
  min: { dimension: "time", factor: 60 }, minute: { dimension: "time", factor: 60 }, minutes: { dimension: "time", factor: 60 },
  h: { dimension: "time", factor: 3600 }, hr: { dimension: "time", factor: 3600 }, hour: { dimension: "time", factor: 3600 }, hours: { dimension: "time", factor: 3600 },
  d: { dimension: "time", factor: 86400 }, day: { dimension: "time", factor: 86400 }, days: { dimension: "time", factor: 86400 },
  b: { dimension: "data", factor: 1 }, byte: { dimension: "data", factor: 1 }, bytes: { dimension: "data", factor: 1 },
  kb: { dimension: "data", factor: 1000 }, mb: { dimension: "data", factor: 1000000 }, gb: { dimension: "data", factor: 1000000000 }, tb: { dimension: "data", factor: 1000000000000 },
  kib: { dimension: "data", factor: 1024 }, mib: { dimension: "data", factor: 1048576 }, gib: { dimension: "data", factor: 1073741824 }, tib: { dimension: "data", factor: 1099511627776 },
  c: { dimension: "temperature", scale: "c" }, "°c": { dimension: "temperature", scale: "c" }, celsius: { dimension: "temperature", scale: "c" },
  f: { dimension: "temperature", scale: "f" }, "°f": { dimension: "temperature", scale: "f" }, fahrenheit: { dimension: "temperature", scale: "f" },
  k: { dimension: "temperature", scale: "k" }, kelvin: { dimension: "temperature", scale: "k" }
}

function toCelsius(value, scale) {
  if (scale === "f") return (value - 32) * 5 / 9
  if (scale === "k") return value - 273.15
  return value
}

function fromCelsius(value, scale) {
  if (scale === "f") return value * 9 / 5 + 32
  if (scale === "k") return value + 273.15
  return value
}

function conversion(input) {
  var match = String(input || "").trim().match(/^(-?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+\-]?\d+)?)\s*([a-z°]+)\s+to\s+([a-z°]+)$/i)
  if (!match) return null
  var from = units[match[2].toLowerCase()]
  var to = units[match[3].toLowerCase()]
  var amount = Number(match[1])
  if (!from || !to || from.dimension !== to.dimension || !isFinite(amount)) return null

  var converted
  if (from.dimension === "temperature") {
    converted = fromCelsius(toCelsius(amount, from.scale), to.scale)
  } else {
    converted = amount * from.factor / to.factor
  }
  var value = formatNumber(converted)
  if (!value) return null
  var result = value + " " + match[3]
  return { kind: "conversion", value: result, copyText: result }
}

function evaluate(input) {
  return conversion(input) || arithmetic(input)
}
