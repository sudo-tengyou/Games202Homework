function loadShaderFromFile(filePath) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', filePath, false); // 使用同步请求
    xhr.send(null);
  
    if (xhr.status === 200) {
        return xhr.responseText;
    } else {
        console.error('无法加载着色器文件:', filePath);
        return null;
    }
}

function loadShaderFile(filename) {

    return new Promise((resolve, reject) => {
        const loader = new THREE.FileLoader();
        loader.load(filename, (data) => {
            resolve(data);
            //console.log(data);
        });
    });
}
