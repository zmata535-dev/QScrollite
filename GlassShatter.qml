import QtQuick

Item {
    id: root

    required property Item targetItem
    property real progress: 0
    property int seed: 1

    x: targetItem.x - 160
    y: targetItem.y - 130
    width: targetItem.width + 320
    height: targetItem.height + 260
    z: targetItem.z + 1
    visible: progress > 0

    Canvas {
        id: shards
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.progress <= 0 || !root.targetItem) return

            var cols = 5
            var rows = 4
            var originX = (width - root.targetItem.width) / 2
            var originY = (height - root.targetItem.height) / 2
            var randomState = root.seed >>> 0
            function randomValue() {
                randomState = (randomState * 1664525 + 1013904223) >>> 0
                return randomState / 4294967296
            }
            var points = []
            for (var y = 0; y <= rows; y++) {
                points[y] = []
                for (var x = 0; x <= cols; x++) {
                    var px = originX + root.targetItem.width * x / cols
                    var py = originY + root.targetItem.height * y / rows
                    if (x > 0 && x < cols) px += (randomValue() - 0.5) * root.targetItem.width / cols * 0.36
                    if (y > 0 && y < rows) py += (randomValue() - 0.5) * root.targetItem.height / rows * 0.36
                    points[y][x] = { x: px, y: py }
                }
            }

            var triangles = []
            for (var row = 0; row < rows; row++) {
                for (var col = 0; col < cols; col++) {
                    var a = points[row][col]
                    var b = points[row][col + 1]
                    var c = points[row + 1][col]
                    var d = points[row + 1][col + 1]
                    if ((row + col) % 2 === 0) triangles.push([a, b, d], [a, d, c])
                    else triangles.push([a, b, c], [b, d, c])
                }
            }

            for (var i = 0; i < triangles.length; i++) {
                var tri = triangles[i]
                var cx = (tri[0].x + tri[1].x + tri[2].x) / 3
                var cy = (tri[0].y + tri[1].y + tri[2].y) / 3
                var dx = cx - width / 2
                var dy = cy - height / 2
                var length = Math.sqrt(dx * dx + dy * dy) || 1
                var delay = randomValue() * 0.2
                var pieceProgress = Math.max(0, Math.min(1, (root.progress - delay) / (1 - delay)))
                var speed = 65 + randomValue() * 115
                var vx = dx / length * speed + (randomValue() - 0.5) * 80
                var vy = dy / length * speed + (randomValue() - 0.5) * 50
                var ox = pieceProgress * vx
                var oy = pieceProgress * vy + pieceProgress * pieceProgress * 88
                var rotation = pieceProgress * (randomValue() - 0.5) * 1.8
                var pieceFade = pieceProgress

                ctx.globalAlpha = (1 - pieceFade) * 0.62
                ctx.beginPath()
                for (var vertex = 0; vertex < 3; vertex++) {
                    var point = tri[vertex]
                    var rx = point.x - cx
                    var ry = point.y - cy
                    var px = cx + rx * Math.cos(rotation) - ry * Math.sin(rotation) + ox
                    var py = cy + rx * Math.sin(rotation) + ry * Math.cos(rotation) + oy
                    if (vertex === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                }
                ctx.closePath()
                ctx.fillStyle = randomValue() > 0.55 ? "#17202f" : "#263548"
                ctx.fill()
                ctx.globalAlpha = 0.48 * (1 - pieceFade)
                ctx.strokeStyle = "#718096"
                ctx.lineWidth = 1.25
                ctx.stroke()
            }
            ctx.globalAlpha = 1
        }

        Connections {
            target: root
            function onProgressChanged() { shards.requestPaint() }
        }
        Connections {
            target: root.targetItem
            function onWidthChanged() { shards.requestPaint() }
            function onHeightChanged() { shards.requestPaint() }
        }
    }
}
