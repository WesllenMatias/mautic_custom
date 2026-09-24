<?php

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$file = __DIR__.$path;

// Se for um arquivo estático existente (CSS, JS, imagens, fontes, etc.), deixa o PHP servir diretamente
if ('/' !== $path && file_exists($file) && !is_dir($file)) {
    return false;
}

// Configura o ambiente para que o Symfony/Mautic reconheça index.php como ponto de entrada
$_SERVER['SCRIPT_FILENAME'] = __DIR__.DIRECTORY_SEPARATOR.'index.php';
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['PHP_SELF'] = '/index.php';

require __DIR__.'/index.php';
