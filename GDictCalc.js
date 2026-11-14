function formatNumber(value) {
    if (!isFinite(value)) return ""
    if (Math.abs(value) < 1e-12) value = 0
    return String(Number(value.toPrecision(10)))
}

function evaluate(input) {
    var source = String(input || "")
    var tokens = []
    var lexer = /\s*(?:(\d+(?:\.\d*)?|\.\d+)(?:([eE][+\-]?\d+))?|([a-zA-Z]+)|(\*\*|[+\-*/^(),!]))/gy
    var position = 0

    while (position < source.length) {
        lexer.lastIndex = position
        var match = lexer.exec(source)
        if (!match) {
            if (/^\s*$/.test(source.slice(position))) break
            return null
        }
        position = lexer.lastIndex
        if (match[1] !== undefined) tokens.push({ type: "number", value: match[1] + (match[2] || "") })
        else if (match[3] !== undefined) tokens.push({ type: "name", value: match[3].toLowerCase() })
        else tokens.push({ type: "symbol", value: match[4] })
    }
    if (!tokens.length) return null

    var index = 0
    function peek(value) {
        return index < tokens.length && tokens[index].value === value
    }
    function take() {
        return tokens[index++]
    }
    function expression() {
        var value = product()
        while (peek("+") || peek("-")) {
            var op = take().value
            var rhs = product()
            value = op === "+" ? value + rhs : value - rhs
        }
        return value
    }
    function product() {
        var value = unary()
        while (peek("*") || peek("/") ) {
            var op = take().value
            var rhs = unary()
            if (op === "/" && rhs === 0) throw new Error("Division by zero")
            value = op === "*" ? value * rhs : value / rhs
        }
        return value
    }
    function unary() {
        if (peek("+")) { take(); return unary() }
        if (peek("-")) { take(); return -unary() }
        return power()
    }
    function power() {
        var value = postfix()
        if (peek("^") || peek("**")) {
            take()
            value = Math.pow(value, unary())
        }
        return value
    }
    function postfix() {
        var value = primary()
        while (peek("!")) {
            take()
            if (value < 0 || value > 170 || Math.floor(value) !== value)
                throw new Error("Factorial needs a whole number from 0 to 170")
            var result = 1
            for (var i = 2; i <= value; i++) result *= i
            value = result
        }
        return value
    }
    function primary() {
        if (index >= tokens.length) throw new Error("Expected a value")
        var token = take()
        if (token.type === "number") return Number(token.value)
        if (token.value === "(") {
            var nested = expression()
            if (!peek(")")) throw new Error("Missing closing parenthesis")
            take()
            return nested
        }
        if (token.type !== "name") throw new Error("Expected a number or function")
        if (token.value === "pi") return Math.PI
        if (token.value === "e") return Math.E
        if (!peek("(")) throw new Error("Use a function like sin(30)")
        take()
        var args = [expression()]
        while (peek(",")) { take(); args.push(expression()) }
        if (!peek(")")) throw new Error("Missing closing parenthesis")
        take()
        var x = args[0]
        var radians = x * Math.PI / 180
        switch (token.value) {
        case "sin": return Math.sin(radians)
        case "cos": return Math.cos(radians)
        case "tan": return Math.tan(radians)
        case "asin": return Math.asin(x) * 180 / Math.PI
        case "acos": return Math.acos(x) * 180 / Math.PI
        case "atan": return Math.atan(x) * 180 / Math.PI
        case "sqrt": return Math.sqrt(x)
        case "cbrt": return Math.cbrt(x)
        case "abs": return Math.abs(x)
        case "ln": return Math.log(x)
        case "log": return Math.log10(x)
        case "exp": return Math.exp(x)
        case "floor": return Math.floor(x)
        case "ceil": return Math.ceil(x)
        case "round": return Math.round(x)
        case "min": return Math.min.apply(Math, args)
        case "max": return Math.max.apply(Math, args)
        default: throw new Error("Unknown function: " + token.value)
        }
    }

    try {
        var value = expression()
        if (index !== tokens.length || !isFinite(value)) return null
        return { value: formatNumber(value) }
    } catch (e) {
        return null
    }
}
