window.RMRPTJS = {
  onMapLoaded() {
    setInterval(window.RMRPTJS.onInterval, window.RMRPTJS.options.interval);
  },
  onInterval() {
    const script = document.createElement("script");
    script.src = `${window.RMRPTJS.options.baseUrl}RMR_progress_tracker_report.js?t=${Date.now()}`;
    script.onload = function() {
      window.RMRPTJS.parseProgress();
      script.remove();
    }
    document.body.appendChild(script);
  },
  prevProgress: null,
  acquiredItems: [],
  parseProgress() {
    let hasChange = false;
    const parseConfigs = [
      { prop: 'items', mapName: 'itemId' },
      { prop: 'checks', mapName: 'checkId' },
    ];


    let progressList = []; // list of current progress, in format of ["CheckOrItemId": value]
    const newItems = []; // a list of new item IDs obtained since last check
    parseConfigs.forEach(({prop, mapName}) => {
      window.RMRPTJS.progress[prop].forEach((progValue, varIndex) => {
        let value = progValue;
        for(let bit = 0; bit <= 7; bit += 1) {
          const bitIndex = varIndex * 8 + bit;
          const id = window.RMRPTJS.maps[mapName][bitIndex];
          if (id) {
            const bitValue = value % 2;
            progressList.push([id, bitValue]);
            if (
              prop === 'items' && bitValue === 1 && !id.match(/^It.+$/) &&
              window.RMRPTJS.prevProgress && window.RMRPTJS.prevProgress[id] === 0
            ) {
              newItems.push(id);
            }
          }
          value = Math.floor(value / 2);
        }
      });
    });

    progressList.push(['SIfg', window.RMRPTJS.progress['ifg']]);
    progressList.push(['SCurrentTitle', window.RMRPTJS.progress['currentTitle']]);
    progressList.push(['SDeathCount', window.RMRPTJS.progress['death']]);

    // available games parsing
    let availableGamesBits = window.RMRPTJS.progress['multiWorldInfo'] >>= 4;
    for (let game = 1; game <= 3; game += 1) {
      progressList.push([`${game}Enabled`, availableGamesBits % 2 === 1 ? 1 : 0]);
      availableGamesBits = availableGamesBits >>= 1;
    }

    window.RMRPTJS.progress['clear'].forEach((value, index) => {
      progressList.push([`${index+1}SFinalClear`, value >= 0x80 ? 1 : 0]);
    });

    progressList = progressList.sort((a, b) => a[0] - b[0]);
    const progress = {};

    let changeCounter = 0;
    progressList.forEach(([id, value]) => {
      progress[id] = value;
      if (window.RMRPTJS.prevProgress && window.RMRPTJS.prevProgress[id] !== value ) {
        hasChange = true;
        changeCounter += 1;
      }
    });

    // If too many flag changes at once, it is likely that we are loading the game for the first
    // time. Reset acquired items in this case.
    if (changeCounter > window.RMRPTJS.options.rebootDetectionNewItemsThreshold) {
      window.RMRPTJS.acquiredItems = [];
      newItems.splice(0, newItems.length);
    }

    if (!window.RMRPTJS.prevProgress || hasChange) {
      window.RMRPTJS.options.callbacks.forEach((callback) => {
        callback(progress, window.RMRPTJS.acquiredItems, newItems);
      });
    }

    // Record current progress before next check
    window.RMRPTJS.prevProgress = progress;
    window.RMRPTJS.acquiredItems = window.RMRPTJS.acquiredItems.concat(newItems);
    // Game is considered started once we start to receive continuous reports
    window.RMRPTJS.gameStarted = !window.RMRPTJS.progress.reportOnBoot;
  },
  options: {
    baseUrl: './progress_tracker_js/',
    rebootDetectionNewItemsThreshold: 32,
    interval: 250,
    callbacks: [],
  },

  // public interface
  configure(options) {
    Object.assign(window.RMRPTJS.options, options);
  },

  start() {
    const script = document.createElement("script");
    script.src = `${window.RMRPTJS.options.baseUrl}RMR_progress_tracker_id_maps.js`;
    script.onload = window.RMRPTJS.onMapLoaded;
    document.body.appendChild(script);
  },
};





