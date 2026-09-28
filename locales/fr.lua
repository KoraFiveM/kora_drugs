return {
    Functions = {
        no_items = 'Vous devez faire %s  %s Ça !',
        timeout = "Lecteur : %s est sur timeout et a lancé l'événement %s",
        distance = "Lecteur : %s est trop loin de l'emplacement requis pour l'événement %s",
    },
    Cocaine = {
        pick = {
            progress = 'Choisir des feuilles de coca',
            target = 'Choisir la feuille de coca',
            icon = 'coca-leaf',
        },
        enter = {
            target = 'Entrez le laboratoire',
            icon = 'Door',
        },
        exit = {
            target = 'Sortie du laboratoire',
            icon = 'Door',
        },
        powdering = {
            target = 'Briser la coca',
            icon = 'coca-leaf',
            progress = 'Briser les feuilles de coca',
        },
        cut = {
            target = 'Couper la cocaïne',
            icon = 'marijuana',
        },
        bag = {
            target = 'Sac en cocaïne',
            icon = 'marijuana',
        },
    },
    Heroin = {
        pick = {
            progress = 'Choisir des coquelicots',
            target = 'Choisir le coquelicot',
            icon = 'poppy',
        },
        drying = {
            target = 'Poppies sèches',
            icon = 'poppy',
            progress = 'Séchage des coquelicots',
        },
        vials = {
            target = "Remplir les flacons d'héroïne",
            icon = 'poppy',
            progress = "Remplir des flacons d'héroïne",
        },
        syringe = {
            target = "Faire de l'héroïne une seringue",
            icon = 'poppy',
            progress = "Faire de l'héroïne une seringue",
        },
    },
    Weed = {
        pick = {
            progress = 'Cueillette de mauvaises herbes',
            target = "Choisir de l'herbe",
            icon = 'weed',
        },
        enter = {
            target = 'Entrez le laboratoire',
            icon = 'Door',
        },
        dry = {
            target = 'Légumes secs',
            icon = 'weed',
            progress = 'Séchage des mauvaises herbes',
        },
        breakNugs = {
            target = "Détruisez l'herbe",
            icon = 'weed',
            progress = 'Briser la mauvaise herbe',
        },
        bag = {
            target = 'Mauvaise herbe',
            icon = 'weed',
            progress = 'La mauvaise herbe',
        },
        rolling = 'Rouleau A',
    },
    crack = {
        cook = {
            target = 'Cuisson',
            icon = 'crack',
            progress = 'Cuisson',
        },
        bagging = {
            target = 'Sac crack',
            icon = 'crack',
            progress = 'Craquage',
        },
    },
    meth = {
        enter = {
            target = 'Entrez le laboratoire',
            icon = 'Door',
        },
        exit = {
            target = 'Sortie du laboratoire',
            icon = 'Door',
        },
        pour = {
            target = 'Verser des produits chimiques',
            icon = 'fa-solid fa-flask',
        },
        tray = {
            target = "Plateau d'accroche",
            icon = 'fa-solid fa-hand-paper',
        },
        heat = {
            target = 'Produits chimiques thermiques',
            icon = 'fa-solid fa-fire',
        },
        smash = {
            target = 'Smash Meth',
            icon = 'fa-solid fa-hammer',
        },
        bag = {
            target = 'Méthon de sac',
            icon = 'fa-solid fa-bag-shopping',
        },
    },
    cornerselling = {
        looking = "Recherche d'un acheteur...",
        buyerFound = 'Acheteur trouvé ! Ils viennent à toi',
        sell = {
            target = "Vendre à l'acheteur",
            icon = 'fa-solid fa-hand-holding',
        },
        sellAlert = {
            title = 'Confirmer la vente',
            message = 'Vendre %s de %s pour $%.2f? ($%.2f chacun)',
            confirmLabel = 'Vendre',
            cancelLabel = 'Baisse',
        },
    },
}
