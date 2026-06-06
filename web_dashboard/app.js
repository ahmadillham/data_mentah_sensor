// DOM Elements
const connectBtn = document.getElementById('connect-btn');
const connectionStatus = document.getElementById('connection-status');
const connectionDot = document.getElementById('connection-dot');
const imuLog = document.getElementById('imu-log');
const hrLog = document.getElementById('hr-log');
const gpsLog = document.getElementById('gps-log');

// Counters
const logCounters = {
    'imu-log': 0,
    'hr-log': 0,
    'gps-log': 0
};
const counterElems = {
    'imu-log': document.getElementById('imu-counter'),
    'hr-log': document.getElementById('hr-counter'),
    'gps-log': document.getElementById('gps-counter')
};

// BLE UUIDs (Matching config.h)
const SPORT_SERVICE_UUID = "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c10";
const CHAR_RAW_UUID      = "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c14";
const CHAR_GPS_UUID      = "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c12";

// State
let bluetoothDevice = null;
let server = null;

// Utility: Get current timestamp
function getTimestamp() {
    const now = new Date();
    const ms = now.getMilliseconds().toString().padStart(3, '0');
    return `[${now.toLocaleTimeString('en-US', { hour12: false })}.${ms}]`;
}

// Utility: Append log to a specific terminal
function appendLog(terminalElem, message, type = 'data') {
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    
    const timestampSpan = document.createElement('span');
    timestampSpan.className = 'timestamp';
    timestampSpan.textContent = getTimestamp();
    
    const messageNode = document.createTextNode(` ${message}`);
    
    if(message.includes("Fix Acquired") || message.includes("WARNING") || message.includes("ERROR")) {
        entry.innerHTML = `<span class="timestamp">${getTimestamp()}</span> <span class="highlight">${message}</span>`;
    } else {
        entry.appendChild(timestampSpan);
        entry.appendChild(messageNode);
    }

    terminalElem.appendChild(entry);
    
    // Auto-scroll
    terminalElem.scrollTop = terminalElem.scrollHeight;

    // Increment Counter
    if (logCounters[terminalElem.id] !== undefined) {
        logCounters[terminalElem.id]++;
        counterElems[terminalElem.id].textContent = logCounters[terminalElem.id];
    }

    // Keep log size manageable (max 100 lines per terminal)
    if (terminalElem.children.length > 100) {
        terminalElem.removeChild(terminalElem.firstChild);
    }
}

// Parse Raw Sensor Data Struct
function handleRawData(event) {
    const view = event.target.value;
    
    // Check byte length to ensure we have exactly 14 bytes
    if (view.byteLength !== 14) return;

    // Little Endian parsing
    const ax = view.getInt16(0, true);
    const ay = view.getInt16(2, true);
    const az = view.getInt16(4, true);
    const gx = view.getInt16(6, true);
    const gy = view.getInt16(8, true);
    const gz = view.getInt16(10, true);
    const hrRaw = view.getUint16(12, true);

    // Render HR Raw Data
    const hrMsg = `ADC_RAW:${hrRaw}`;
    appendLog(hrLog, hrMsg, 'data');

    // Render IMU Raw Data
    const imuMsg = `AX:${ax} AY:${ay} AZ:${az} | GX:${gx} GY:${gy} GZ:${gz}`;
    appendLog(imuLog, imuMsg, 'data');
}

// Parse GPS Data Struct
function handleGpsData(event) {
    const view = event.target.value;
    
    const lat = view.getFloat64(0, true).toFixed(6);
    const lng = view.getFloat64(8, true).toFixed(6);
    const speed = view.getFloat32(16, true).toFixed(1);
    const dist = view.getFloat32(20, true).toFixed(2);
    const sats = view.getUint8(24);
    const fix = view.getUint8(25);

    if (fix === 1) {
        appendLog(gpsLog, `LAT:${lat} LNG:${lng} SPD:${speed}km/h DIST:${dist}km SATS:${sats}`, 'data');
    } else {
        appendLog(gpsLog, `Waiting for Fix... (Satellites: ${sats})`, 'warn');
    }
}

// Disconnect handler
function onDisconnected(event) {
    console.log("Device disconnected.");
    resetUI();
}

// Reset UI state
function resetUI() {
    bluetoothDevice = null;
    server = null;
    connectionStatus.textContent = 'Disconnected';
    connectionDot.className = 'dot disconnected';
    connectBtn.innerHTML = `CONNECT DEVICE`;
}

// Web Bluetooth Connection Logic
connectBtn.addEventListener('click', async () => {
    if (bluetoothDevice && bluetoothDevice.gatt.connected) {
        // Disconnect
        bluetoothDevice.gatt.disconnect();
        return;
    }

    try {
        if (!navigator.bluetooth) {
            console.error("Web Bluetooth API not supported in this browser. Please use Chrome/Edge and ensure you are running on localhost or HTTPS.");
            return;
        }

        console.log("Requesting Bluetooth Device...");
        
        bluetoothDevice = await navigator.bluetooth.requestDevice({
            filters: [{ namePrefix: "SportTrackerRaw" }],
            optionalServices: [SPORT_SERVICE_UUID]
        });

        bluetoothDevice.addEventListener('gattserverdisconnected', onDisconnected);

        console.log(`Connecting to GATT Server on ${bluetoothDevice.name}...`);
        
        connectBtn.innerHTML = `CONNECTING...`;
        
        server = await bluetoothDevice.gatt.connect();
        
        console.log("Connected to GATT Server. Getting Services...");
        const service = await server.getPrimaryService(SPORT_SERVICE_UUID);

        // Subscribe to Raw Sensor Data
        const rawChar = await service.getCharacteristic(CHAR_RAW_UUID);
        await rawChar.startNotifications();
        rawChar.addEventListener('characteristicvaluechanged', handleRawData);
        console.log("Subscribed to Raw Sensor Characteristic.");

        // Subscribe to GPS Data
        const gpsChar = await service.getCharacteristic(CHAR_GPS_UUID);
        await gpsChar.startNotifications();
        gpsChar.addEventListener('characteristicvaluechanged', handleGpsData);
        console.log("Subscribed to GPS Characteristic.");

        // Update UI
        connectionStatus.textContent = 'Connected (BLE)';
        connectionDot.className = 'dot connected';
        connectBtn.innerHTML = `DISCONNECT`;
        console.log("Telemetry stream established successfully.");

    } catch (error) {
        console.error(`ERROR: ${error.message}`);
        resetUI();
    }
});
