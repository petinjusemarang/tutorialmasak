--==========================================================
-- MERDEKA CLEAR MAP
--
-- Alur pemakaian:
-- 1. Jalanin script ini. Platform solid otomatis muncul di
--    tiap landmark (respawn, spawner, koper spawn, tiap
--    ATM) sebagai pijakan pengganti Terrain/Map yang nanti
--    bakal dihapus, dan lantai kotak raksasa juga langsung
--    kebentuk. GUI auto-quest BCA (di bawah prelude ini)
--    juga langsung kebentuk, tapi loop otomatisnya NUNGGU
--    sampai map di-clear.
-- 2. Fully-auto, ga ada lagi tombol CLEAR MAP terpisah --
--    tinggal pencet tombol AUTO ON/OFF di GUI BCA QUEST (di
--    bawah). Begitu di-ON-in, otomatis: wipe folder-folder
--    obstruksi map lama (platform & lantai kotak TIDAK ikut
--    kehapus, folder terpisah) -> mulai loop quest -- ga
--    perlu klik konfirmasi terpisah.
--==========================================================

--==========================================================
-- DELETE BACKPACK -- BENERAN PALING AWAL
--
-- Dipindah ke SINI (baris paling atas file) SENGAJA -- taro
-- di section "BCA QUEST" (jauh di bawah) artinya baru
-- kepanggil SETELAH seluruh prelude clear-map (build
-- landmark platform, lantai kotak, dst) selesai jalan
-- duluan. Backpack bawaan Roblox ga kepakai sama sekali di
-- quest ini, jadi dihapus di sini -- literally hal PERTAMA
-- yang dikerjakan script, sebelum baris lain manapun jalan.
--==========================================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer


local function deleteBackpack()

    local backpack =
        player:FindFirstChild("Backpack")

    if backpack then

        backpack:Destroy()

    end

end


deleteBackpack()


player.ChildAdded:Connect(function(child)

    if child.Name == "Backpack" then

        task.wait()

        child:Destroy()

    end

end)


--==========================================================
-- ANTI DOUBLE RUN (prelude clear-map doang, quest-nya
-- masih pakai guard sendiri di kodenya sendiri)
--==========================================================

if getgenv()._merdekaClearMapRunning then

    print("[MERDEKA-CLEARMAP] Prelude already loaded, skip prelude.")

else

    getgenv()._merdekaClearMapRunning = true


    --==========================================================
    -- LANDMARK DATA (koordinat dari data collection manual)
    --
    -- "cframe" = titik acuan (level lantai/kaki di titik itu).
    -- Platform diletakkan supaya PERMUKAAN ATASnya pas di
    -- ketinggian ini, bukan titik tengahnya.
    --==========================================================

    local LANDMARKS = {

        { name = "Respawn",        cframe = CFrame.new(-2197.001709, 19.069168, 1447.533691),  size = Vector3.new(150, 4, 150) },

        --==================================================
        -- "NpcStartJob" SENGAJA DIHAPUS dari sini -- Y-nya
        -- (14.13) kepepet banget deket LANTAI KOTAK (Y
        -- FLOOR_Y=13.37, tebal FLOOR_THICKNESS=2, jadi
        -- permukaan lantai ada di rentang Y 11.37-13.37).
        -- Slab NpcStartJob (rentang Y 10.13-14.13) NUMPUK
        -- FISIK sama lantai di seluruh rentang itu -- jadi
        -- ada "gundukan"/tembok kecil ~0.76 stud yang
        -- nongol persis di TENGAH lantai datar, di lokasi
        -- yang lumayan sering dilewatin mobil pas nyetir ke
        -- ATM manapun -- itu penyebab mobil "tiba-tiba
        -- ngurangin kecepatan sampe 0" walau masih jauh dari
        -- tujuan (nabrak gundukan ini, bukan macet beneran).
        -- Landmark ini juga UDAH KETUTUP LANTAI KOTAK (posisi
        -- X/Z-nya ada di dalam bounding box lantai), jadi
        -- platform terpisah di sini emang udah ga perlu lagi.
        --==================================================

        --==================================================
        -- "CarSpawnerNpc" (dulu titik terpisah buat NPC
        -- satpam/car spawner) SENGAJA dihapus dari sini --
        -- footprint-nya (250x250) numpuk sama CarSpawnerArea
        -- (500x500) yang cuma ~23 stud jauhnya, tapi Y-nya
        -- beda ~1 stud lebih tinggi. Mobil yang spawn di Y
        -- CarSpawnerArea jadi ke-embed di dalam slab
        -- CarSpawnerNpc yang lebih tinggi itu ("nyebur").
        -- CarSpawnerArea sendirian udah lebih dari cukup
        -- nutupin area ini (dan Y-nya udah pas sama
        -- carSpawnPosition asli di quest logic).
        --==================================================

        { name = "CarSpawnerArea", cframe = CFrame.new(1860.007080, 13.370062, -4897.120605),   size = Vector3.new(500, 4, 500) },

        --==================================================
        -- "KoperSpawn" (platform landmark, BUKAN folder game
        -- "KoperSpawn" yang dipakai Step 5 -- itu beda objek,
        -- tetap ada & tetap dipakai) SENGAJA DIHAPUS dari sini
        -- -- X/Z-nya (1779, -4644) jatuh DI DALAM bounding box
        -- lantai kotak (yang mencakup CarSpawnerArea ± 400
        -- stud padding), tapi permukaan atasnya (Y=21.16) ada
        -- ~8 stud MELAYANG DI ATAS permukaan lantai (Y=13.37)
        -- -- persis kasus yang sama kayak NpcStartJob dulu:
        -- jadi "lantai dobel" yang nongol tepat di deket area
        -- NPC start/koper spawn, bikin mobil nabrak
        -- pinggirnya pas lewat situ. Lantai kotak udah nutupin
        -- area ini sepenuhnya, platform terpisah ga perlu lagi.
        --==================================================

        --==================================================
        -- "Parkir1..10" SENGAJA DIHAPUS dari sini -- mobil
        -- ga lagi di-teleport (wrapToLocationSoft) naik/turun
        -- ke platform parkir terpisah ini (lihat Step 7),
        -- soalnya ketinggiannya beda dari LANTAI KOTAK dan
        -- pinggirnya jadi kayak tembok/curb yang bikin mobil
        -- nabrak & nyangkut. Sekarang mobil cukup BERHENTI DI
        -- LANTAI begitu udah sejajar (X/Z) sama titik parkir
        -- -- ga perlu papan terpisah lagi.
        --
        -- Platform ATM di bawah ini masih TETAP ADA tapi
        -- dikecilin lagi (bukan 220 lagi) -- bukan buat mobil
        -- (mobil ga pernah ke sana), tapi buat PLAYER berpijak
        -- pas di-teleport (Step 11) ke Screen_ATM_01 buat
        -- ngerjain minigame -- titik itu ketinggiannya beda
        -- jauh dari lantai kotak (8-38 stud di atasnya), jadi
        -- tetap butuh pijakan sendiri di situ.
        --==================================================

        { name = "ATM1",    cframe = CFrame.new(6381.612793, 21.813574, -7198.071289),   size = Vector3.new(20, 4, 20) },

        { name = "ATM2",    cframe = CFrame.new(2220.207031, 28.077150, -4594.378418),   size = Vector3.new(20, 4, 20) },

        { name = "ATM3",    cframe = CFrame.new(832.588562, 22.856527, -3819.309082),    size = Vector3.new(20, 4, 20) },

        { name = "ATM4",    cframe = CFrame.new(-1907.274292, 23.770407, 1141.594482),   size = Vector3.new(20, 4, 20) },

        { name = "ATM5",    cframe = CFrame.new(-4522.882324, 25.727510, 4376.390137),   size = Vector3.new(20, 4, 20) },

        { name = "ATM6",    cframe = CFrame.new(-4506.811523, 23.649044, 9662.726562),   size = Vector3.new(20, 4, 20) },

        { name = "ATM7",    cframe = CFrame.new(-475.867584, 27.291304, 8732.920898),    size = Vector3.new(20, 4, 20) },

        { name = "ATM8",    cframe = CFrame.new(-232.495178, 23.529095, 10729.978516),   size = Vector3.new(20, 4, 20) },

        { name = "ATM9",    cframe = CFrame.new(1586.373901, 52.160751, 871.395325),     size = Vector3.new(20, 4, 20) },

        { name = "ATM10",    cframe = CFrame.new(1990.800537, 23.063835, -3526.621582),  size = Vector3.new(20, 4, 20) },

    }


    local LANDMARK_FOLDER_NAME = "MerdekaGroundPlatforms"


    local function buildLandmarkPlatforms()

        local existing =
            workspace:FindFirstChild(
                LANDMARK_FOLDER_NAME
            )

        if existing then
            existing:Destroy()
        end


        local folder =
            Instance.new("Folder")

        folder.Name =
            LANDMARK_FOLDER_NAME

        folder.Parent =
            workspace


        for _, landmark in ipairs(LANDMARKS) do

            local part =
                Instance.new("Part")

            part.Name =
                landmark.name

            part.Size =
                landmark.size

            part.Anchored = true
            part.CanCollide = true
            part.CanTouch = true
            part.CanQuery = true

            part.Material =
                Enum.Material.Concrete

            part.Color =
                Color3.fromRGB(80, 80, 90)

            part.TopSurface =
                Enum.SurfaceType.Smooth

            part.BottomSurface =
                Enum.SurfaceType.Smooth


            local topPosition =
                landmark.cframe.Position

            local centerPosition =
                topPosition -
                Vector3.new(
                    0,
                    landmark.size.Y / 2,
                    0
                )

            part.CFrame =
                CFrame.new(
                    centerPosition
                )

            part.Parent = folder

        end


        print(
            "[MERDEKA-CLEARMAP] Landmark platforms dibuat: " ..
            #LANDMARKS
        )

    end


    buildLandmarkPlatforms()


    --==========================================================
    -- "LANTAI KOTAK" — SATU LEMPENG RAKSASA SEJAJAR TANAH
    -- YANG NUTUPIN SEMUA ATM
    --
    -- Eksperimen sebelumnya (satu JALUR LURUS 1D, 10rb stud)
    -- motong "jarak yang kehitung buat gaji" dari "kemana
    -- mobil beneran perlu pergi" -- mobil ditarik di garis
    -- FIXED yang ga ada hubungannya sama arah ATM tujuan,
    -- baru abis itu di-teleport paksa ke ATM sebenarnya.
    -- Jalan, tapi berasa hack -- ga ada geometri nyata yang
    -- menghubungkan spawn ke tiap ATM.
    --
    -- Gantinya: bukan garis 1D, tapi satu PLAT DATAR 2D
    -- raksasa yang SEJAJAR (Y sama persis) sama
    -- CarSpawnerArea -- BUKAN diambangkan di langit --
    -- mencakup bounding box posisi CarSpawnerArea + SEMUA
    -- 10 ATM sekaligus, plus margin (FLOOR_PADDING). Aman
    -- ditaro sejajar tanah gitu karena CLEAR MAP udah
    -- ngewipe map/terrain lama duluan sebelum auto-quest
    -- jalan -- ga ada lagi obstacle di ketinggian itu.
    -- Karena satu plat solid yang sama nutupin semua titik
    -- itu, mobil bisa nyetir LURUS dari titik manapun di
    -- plat ke titik manapun lainnya (tepat di atas ATM
    -- tujuan) tanpa pernah kepotong/ketabrak apapun -- GA
    -- ADA LAGI jalur per-ATM, ramp, belokan, atau
    -- obstacle-avoidance sama sekali, tinggal garis lurus
    -- doang.
    --
    -- Alur satu pengantaran (liat Step 7 di bawah):
    -- 1. Mobil (+ player) di-teleport INSTAN ke titik ENTRY
    --    (tepat di CarSpawnerArea, sejajar lantai) -- dari
    --    manapun mobil sekarang berada, jadi "balik ke
    --    spawner" kejadian otomatis tiap Step 7.
    -- 2. Ditarik (wrapDriveStraightTo, W ditahan terus biar
    --    kehitung gaji) LURUS dari titik entry itu ke titik
    --    SEJAJAR LANTAI TEPAT DI ATAS/BAWAH ATM TUJUAN
    --    SEBENARNYA (bukan garis dekoi lagi) -- selama masih
    --    di dalam bounding box plat, dijamin ga akan pernah
    --    jatuh/nyangkut.
    -- 3. Begitu sampai di titik lantai deket ATM tujuan,
    --    teleport (wrapToLocationSoft, hover naik/turun
    --    otomatis ke arah manapun) ke titik parkir aman
    --    ATM itu yang sebenarnya.
    -- 4. Turun mobil, ambil koper dari bagasi, isi ATM
    --    (Step 8-12, GA BERUBAH).
    -- 5. Balik ke Step 6 (naik mobil) -> Step 7 lagi -- yang
    --    otomatis teleport BALIK ke titik entry dari manapun
    --    mobil itu sekarang berada.
    --==========================================================

    local FLOOR_FOLDER_NAME = "MerdekaFloorBox"

    local FLOOR_THICKNESS = 2

    -- Batas panjang per part, di bawah limit ukuran part
    -- Roblox (2048 stud/axis) -- plat totalnya jauh lebih
    -- lebar dari itu, makanya dipecah jadi grid potongan.
    local FLOOR_MAX_CHUNK = 1800

    -- Margin di sekeliling bounding box ATM/spawner, biar
    -- mobil ga pernah nyaris/ngelewatin pinggir plat pas
    -- lagi manuver/arrive-distance di dekat tujuan.
    local FLOOR_PADDING = 400


    local floorMinX = math.huge
    local floorMaxX = -math.huge
    local floorMinZ = math.huge
    local floorMaxZ = -math.huge

    local carSpawnerFloorPosition = nil


    for _, landmark in ipairs(LANDMARKS) do

        if
            landmark.name == "CarSpawnerArea"
            or landmark.name:match("^ATM%d+$")
        then

            local pos =
                landmark.cframe.Position

            if landmark.name == "CarSpawnerArea" then

                carSpawnerFloorPosition = pos

            end

            if pos.X < floorMinX then floorMinX = pos.X end
            if pos.X > floorMaxX then floorMaxX = pos.X end
            if pos.Z < floorMinZ then floorMinZ = pos.Z end
            if pos.Z > floorMaxZ then floorMaxZ = pos.Z end

        end

    end

    floorMinX = floorMinX - FLOOR_PADDING
    floorMaxX = floorMaxX + FLOOR_PADDING
    floorMinZ = floorMinZ - FLOOR_PADDING
    floorMaxZ = floorMaxZ + FLOOR_PADDING


    --==================================================
    -- SEJAJAR SAMA TITIK SPAWN CAR -- BUKAN DI LANGIT
    --
    -- Percobaan pertama nempatin lantai di atas ATM
    -- PALING TINGGI (kayak BASECAMP_POSITION di versi
    -- hub-and-spoke) -- itu keliru buat kasus ini: user
    -- MINTA lantainya SEJAJAR (Y sama persis) sama
    -- CarSpawnerArea, bukan diambangkan di langit.
    --
    -- Ini AMAN dilakuin justru karena "CLEAR MAP" udah
    -- ngewipe terrain/map lama duluan sebelum auto-quest
    -- mulai jalan (lihat clearMap() + gerbang
    -- MerdekaMapCleared di bawah) -- begitu map lama
    -- bersih, ketinggian tanah asli (CarSpawnerArea) udah
    -- ga ada lagi yang ngalangin, jadi lantai sejajar ini
    -- tetep 100% bebas obstacle, ga perlu diambangkan
    -- tinggi-tinggi lagi.
    --
    -- FLOOR_Y_OFFSET -- lantainya kerasa kerendahan pas
    -- dicoba, dinaikin dikit dari persis sejajar
    -- CarSpawnerArea. GANTI ANGKA INI AJA buat naik/
    -- turunin ketinggian lantai lebih lanjut.
    --==================================================

    local FLOOR_Y_OFFSET = 7

    local FLOOR_Y =
        carSpawnerFloorPosition
        and carSpawnerFloorPosition.Y + FLOOR_Y_OFFSET
        or 0


    local function buildFloorBox()

        local existing =
            workspace:FindFirstChild(
                FLOOR_FOLDER_NAME
            )

        if existing then
            existing:Destroy()
        end


        local folder =
            Instance.new("Folder")

        folder.Name =
            FLOOR_FOLDER_NAME

        folder.Parent =
            workspace


        local totalWidth =
            floorMaxX - floorMinX

        local totalDepth =
            floorMaxZ - floorMinZ

        local chunkCountX =
            math.max(
                1,
                math.ceil(totalWidth / FLOOR_MAX_CHUNK)
            )

        local chunkCountZ =
            math.max(
                1,
                math.ceil(totalDepth / FLOOR_MAX_CHUNK)
            )

        local chunkWidth =
            totalWidth / chunkCountX

        local chunkDepth =
            totalDepth / chunkCountZ

        local partCount = 0


        for ix = 1, chunkCountX do

            for iz = 1, chunkCountZ do

                local centerX =
                    floorMinX +
                    chunkWidth * (ix - 0.5)

                local centerZ =
                    floorMinZ +
                    chunkDepth * (iz - 0.5)


                local part =
                    Instance.new("Part")

                part.Name =
                    "FloorChunk_" .. ix .. "_" .. iz

                -- +4 biar potongan-potongan nempel rapat
                -- tanpa celah tipis di sambungannya.
                part.Size =
                    Vector3.new(
                        chunkWidth + 4,
                        FLOOR_THICKNESS,
                        chunkDepth + 4
                    )

                part.CFrame =
                    CFrame.new(
                        centerX,
                        FLOOR_Y - FLOOR_THICKNESS / 2,
                        centerZ
                    )

                part.Anchored = true
                part.CanCollide = true
                part.CanTouch = true
                part.CanQuery = true

                part.Material =
                    Enum.Material.Concrete

                part.Color =
                    Color3.fromRGB(60, 60, 70)

                part.TopSurface =
                    Enum.SurfaceType.Smooth

                part.BottomSurface =
                    Enum.SurfaceType.Smooth

                part.Parent = folder


                partCount =
                    partCount + 1

            end

        end


        print(
            "[MERDEKA-CLEARMAP] Lantai kotak dibuat: " ..
            partCount ..
            " part (" ..
            chunkCountX .. "x" .. chunkCountZ ..
            ") di Y=" .. FLOOR_Y ..
            ", nutupin X[" .. floorMinX .. ".." .. floorMaxX ..
            "] Z[" .. floorMinZ .. ".." .. floorMaxZ .. "]."
        )

    end


    buildFloorBox()


    --==========================================================
    -- EXPOSE KE QUEST LOGIC DI BAWAH
    --
    -- Section ini ada di dalam guard anti-double-run, jadi
    -- local-nya ga keliatan sama kode quest (di luar guard).
    -- +1 stud biar mobil ga ke-embed pas di-teleport pas di
    -- atas permukaan lantainya.
    --==========================================================

    getgenv().MerdekaFloorY =
        FLOOR_Y

    getgenv().MerdekaFloorEntryPoint =
        carSpawnerFloorPosition
        and Vector3.new(
            carSpawnerFloorPosition.X,
            FLOOR_Y + 1,
            carSpawnerFloorPosition.Z
        )


    --==========================================================
    -- WHITELIST — JANGAN PERNAH DIHAPUS
    --==========================================================

    local WHITELIST_NAMES = {

        MY_BCA_COLLAB = true,
        Vehicles = true,
        Lives = true,
        BankCourierRoute = true,
        __BankCourierTarget = true,

    }


    --==========================================================
    -- BLACKLIST — DIHAPUS SAAT CLEAR MAP
    --
    -- "Lives" SENGAJA ga dimasukin walaupun awalnya kesebut di
    -- data mentah user — sudah dikonfirmasi Lives itu KEEP,
    -- bukan wipe.
    --==========================================================

    local BLACKLIST_NAMES = {

        "2026LahkokginiTitano",
        "Asset",
        "Client",
        "EditableBuilds",
        "Etc",
        "Hover",
        "LightingAmbientRevamp",
        "MELAWAI",
        "Map",
        "Minigames",
        "ModificationCache",
        "ModificationPart",
        "MoreVehicle",
        "NPC",
        "Rambu and props",
        "Refund",
        "SATPAM_NAVBLOCK",
        "StreetLampTemplate",
        "TeleportFolder",
        "Train",
        "Train2",
        "ZoneFolder",
        "duplikat temp",
        "ArrowModel",
        "Flag",

    }


    --==========================================================
    -- INDEX-BASED TARGETS
    --
    -- Beberapa entri di data user cuma direferensikan lewat
    -- index Workspace:GetChildren() (nama duplikat/kosong).
    -- RISKY kalau urutan children Workspace berubah dari saat
    -- data ini dikumpulkan -- makanya tiap item di-print
    -- Name+ClassName-nya sebelum di-Destroy buat verifikasi
    -- manual di output console.
    --==========================================================

    local BLACKLIST_INDICES = {
        27, 28, 29, 30, 31, 32, 33, 34,
    }


    local WIPE_TERRAIN = true


    local function isWhitelisted(instance)

        if not instance then
            return true
        end

        return
            WHITELIST_NAMES[instance.Name] ==
            true

    end


    local function clearMap()

        print("[MERDEKA-CLEARMAP] ===== CLEAR MAP START =====")


        --==================================================
        -- BY NAME
        --==================================================

        for _, name in ipairs(BLACKLIST_NAMES) do

            local target =
                workspace:FindFirstChild(name)

            if target then

                if isWhitelisted(target) then

                    warn(
                        "[MERDEKA-CLEARMAP] SKIP (whitelisted): " ..
                        name
                    )

                else

                    print(
                        "[MERDEKA-CLEARMAP] Deleting: " ..
                        name ..
                        " (" ..
                        target.ClassName ..
                        ")"
                    )

                    target:Destroy()

                end

            else

                print(
                    "[MERDEKA-CLEARMAP] Not found (skip): " ..
                    name
                )

            end

        end


        --==================================================
        -- BY INDEX (snapshot dulu, hapus dari index besar
        -- ke kecil supaya index yang belum diproses ga geser)
        --==================================================

        local snapshot =
            workspace:GetChildren()

        local sortedIndices = {}

        for _, idx in ipairs(BLACKLIST_INDICES) do
            table.insert(sortedIndices, idx)
        end

        table.sort(
            sortedIndices,
            function(a, b)
                return a > b
            end
        )


        for _, idx in ipairs(sortedIndices) do

            local target =
                snapshot[idx]

            if target and target.Parent then

                if isWhitelisted(target) then

                    warn(
                        "[MERDEKA-CLEARMAP] SKIP index " ..
                        idx ..
                        " (whitelisted): " ..
                        target.Name
                    )

                else

                    print(
                        "[MERDEKA-CLEARMAP] Deleting index " ..
                        idx ..
                        ": " ..
                        target.Name ..
                        " (" ..
                        target.ClassName ..
                        ")"
                    )

                    target:Destroy()

                end

            else

                warn(
                    "[MERDEKA-CLEARMAP] Index " ..
                    idx ..
                    " tidak valid / instance sudah hilang"
                )

            end

        end


        --==================================================
        -- TERRAIN
        --==================================================

        if WIPE_TERRAIN then

            local terrain =
                workspace:FindFirstChildOfClass(
                    "Terrain"
                )

            if terrain then

                print("[MERDEKA-CLEARMAP] Clearing Terrain...")

                terrain:Clear()

            end

        end


        print("[MERDEKA-CLEARMAP] ===== CLEAR MAP DONE =====")

    end


    --==========================================================
    -- clearMap() itu LOCAL ke block if/else ini (scope-nya
    -- Lua ngebatesin variabel local di dalam if/else cuma
    -- keliatan di dalam block itu doang) -- padahal tombol
    -- AUTO ON/OFF yang manggil dia sekarang ada di section
    -- "BCA QUEST" yang jaraknya jauh di bawah, DI LUAR block
    -- ini. Expose lewat getgenv() (pola yang sama kayak
    -- MerdekaFloorY/MerdekaFloorEntryPoint di atas) biar bisa
    -- dipanggil dari sana.
    --==========================================================

    getgenv().MerdekaClearMap =
        clearMap


    --==========================================================
    -- getgenv().MerdekaMapCleared -- GERBANG YANG DITUNGGU LOOP
    -- AUTO DI BAWAH.
    --
    -- Dulu di-set true lewat tombol "CLEAR MAP" (2x klik
    -- konfirmasi) di panel GUI terpisah "Merdeka Clear Map" --
    -- panel itu SENGAJA DIHAPUS sekarang, GUI diperkecil jadi
    -- cuma tombol AUTO ON/OFF (lihat "BCA QUEST -- AUTO LOOP"
    -- di bawah). Begitu tombol itu di-ON-in PERTAMA KALI,
    -- deleteBackpack() -> clearMap() -> flag ini langsung
    -- di-set true dari situ -- ga perlu tombol/klik konfirmasi
    -- terpisah lagi di sini.
    --==========================================================

    getgenv().MerdekaMapCleared = false


    print("[MERDEKA-CLEARMAP] Prelude loaded (map wipe otomatis lewat tombol AUTO ON/OFF).")

end


--==========================================================
-- BCA QUEST — AUTO LOOP
--
-- Hasil merge dari bcajob.lua (13 step manual) jadi satu
-- siklus otomatis:
--
-- 1 -> 2 -> 3 -> 4 -> 5 ->
-- [6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12] diulang PER KOPER
-- (tiap koper bisa beda ATM tujuan, jadi naik mobil ->
-- antar ke ATM -> keluar mobil -> ambil koper -> setor
-- diulang tiap putaran) sampai semua koper terkirim ->
-- balik ke 1 (ngobrol lagi sama NPC) -> ulang.
--==========================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")


--==========================================================
-- PLAYER GUI
--
-- `player` & `deleteBackpack` UDAH di-declare di baris
-- PALING ATAS file (sebelum prelude clear-map) -- tetap
-- ke-scope di sini (local top-level Lua keliatan di seluruh
-- sisa chunk), ga perlu re-declare/re-panggil lagi.
--==========================================================

local playerGui = player:WaitForChild("PlayerGui")


--==========================================================
-- REMOVE OLD GUI
--==========================================================

local oldGui = playerGui:FindFirstChild("BCAQuestAutoGUI")

if oldGui then
    oldGui:Destroy()
end


--==========================================================
-- SCREEN GUI
--==========================================================

local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name = "BCAQuestAutoGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

ScreenGui.Parent = playerGui


--==========================================================
-- MAIN -- KOTAK KECIL: TOMBOL ON/OFF + SALDO MYBCA
--
-- GUI lama (Title, Close, Status besar, TimeInput manual,
-- TimerLabel) diperkecil jadi cuma 2 elemen -- tombol AUTO
-- ON/OFF (sekaligus trigger deleteBackpack -> clearMap ->
-- mulai loop di klik ON pertama) sama label saldo MyBCA
-- (live, diambil dari GUI phone in-game).
--==========================================================

local Main = Instance.new("Frame")

Main.Name = "Main"

Main.Size = UDim2.fromOffset(220, 110)

Main.Position = UDim2.new(
    0.5,
    -110,
    0.5,
    -55
)

Main.BackgroundColor3 =
    Color3.fromRGB(25, 25, 25)

Main.BorderSizePixel = 0
Main.Active = true

Main.Parent = ScreenGui


local MainCorner = Instance.new("UICorner")

MainCorner.CornerRadius =
    UDim.new(0, 10)

MainCorner.Parent = Main


--==========================================================
-- STATUS -- TERSEMBUNYI
--
-- Ratusan Status.Text = "..." tersebar di seluruh step
-- function (dipakai buat debugging internal) -- daripada
-- hapus semuanya satu-satu, TextLabel-nya TETAP ADA (biar
-- semua assignment itu tetap valid, ga error), tapi
-- Visible = false jadi ga nongol lagi di GUI kecil ini.
--==========================================================

local Status = Instance.new("TextLabel")

Status.Size = UDim2.fromOffset(1, 1)
Status.BackgroundTransparency = 1
Status.Text = "Status: Ready"
Status.Visible = false

Status.Parent = Main


--==========================================================
-- TOGGLE AUTO ON/OFF
--
-- OFF -> ON (PERTAMA KALI SAJA, lihat hasStartedOnce) =
-- deleteBackpack() -> clearMap() (lewat getgenv().
-- MerdekaClearMap, di-expose dari prelude di atas) ->
-- getgenv().MerdekaMapCleared = true (gerbang yang ditunggu
-- loop auto-quest di paling bawah file). Klik OFF sesudahnya
-- cuma pause (autoRunning = false, sama kayak sebelumnya) --
-- klik ON lagi ga akan re-trigger delete backpack/clear map.
--==========================================================

local autoRunning = false
local hasStartedOnce = false


local Toggle = Instance.new("TextButton")

Toggle.Size = UDim2.new(1, -20, 0, 40)

Toggle.Position = UDim2.fromOffset(10, 10)

Toggle.BackgroundColor3 =
    Color3.fromRGB(110, 50, 50)

Toggle.BorderSizePixel = 0

Toggle.Text = "AUTO: OFF"

Toggle.TextColor3 =
    Color3.fromRGB(255, 255, 255)

Toggle.TextSize = 16

Toggle.Font =
    Enum.Font.GothamBold

Toggle.Parent = Main


local ToggleCorner = Instance.new("UICorner")

ToggleCorner.CornerRadius =
    UDim.new(0, 8)

ToggleCorner.Parent = Toggle


Toggle.MouseButton1Click:Connect(function()

    autoRunning =
        not autoRunning

    if autoRunning then

        Toggle.Text = "AUTO: ON"

        Toggle.BackgroundColor3 =
            Color3.fromRGB(40, 120, 70)

        if not hasStartedOnce then

            hasStartedOnce = true

            task.spawn(function()

                deleteBackpack()

                local clearMapFn =
                    getgenv().MerdekaClearMap

                if clearMapFn then
                    clearMapFn()
                end

                getgenv().MerdekaMapCleared = true

            end)

        end

    else

        Toggle.Text = "AUTO: OFF"

        Toggle.BackgroundColor3 =
            Color3.fromRGB(110, 50, 50)

    end

end)


--==========================================================
-- SALDO MYBCA (LIVE)
--==========================================================

local SaldoLabel = Instance.new("TextLabel")

SaldoLabel.Size = UDim2.new(1, -20, 0, 40)

SaldoLabel.Position = UDim2.fromOffset(10, 58)

SaldoLabel.BackgroundColor3 =
    Color3.fromRGB(35, 35, 42)

SaldoLabel.BorderSizePixel = 0

SaldoLabel.Text = "Rp -"

SaldoLabel.TextColor3 =
    Color3.fromRGB(100, 255, 130)

SaldoLabel.TextSize = 18

SaldoLabel.Font =
    Enum.Font.GothamBold

SaldoLabel.Parent = Main


local SaldoLabelCorner = Instance.new("UICorner")

SaldoLabelCorner.CornerRadius =
    UDim.new(0, 8)

SaldoLabelCorner.Parent = SaldoLabel


--==========================================================
-- WAKTU TEMPUH (WRAP TIMED) -- DIPATENKAN
--
-- Dulu ada TextBox input manual + TimerLabel realtime buat
-- cari-cari angka yang pas -- GUI-nya sekarang diperkecil
-- jadi cuma ON/OFF + saldo doang, jadi angka hasil coba-coba
-- itu (65 detik) dipatenkan langsung di sini, ga bisa
-- diganti lagi lewat GUI.
--==========================================================

local wrapTravelTimeSeconds = 65


--==========================================================
-- SALDO MYBCA -- CARI LABEL + FORMAT ANGKA
--
-- Text aslinya (Accumulated) udah keformat sendiri sama
-- game ("Rp. 113,404,904" dst) -- tapi biar ga gantung ke
-- format bawaan game (bisa aja beda: titik/koma, ada "Rp."
-- atau nggak), semua karakter NON-ANGKA di-strip dulu, baru
-- angka mentahnya di-format ULANG sendiri (koma per 3 digit).
--==========================================================

local function formatWithCommas(digits)

    local reversed =
        digits:reverse()

    local grouped =
        reversed:gsub("(%d%d%d)", "%1,")

    grouped =
        grouped:reverse()

    grouped =
        grouped:gsub("^,", "")

    return grouped

end


local function getSaldoAccumulatedLabel()

    local phoneGui =
        playerGui:FindFirstChild("ACTUAL NEW PHONE")

    local container =
        phoneGui
        and phoneGui:FindFirstChild("Container")

    local holder =
        container
        and container:FindFirstChild("Holder")

    local appContainer =
        holder
        and holder:FindFirstChild("AppContainer")

    local myBca =
        appContainer
        and appContainer:FindFirstChild("MyBca")

    local poketRupiah =
        myBca
        and myBca:FindFirstChild("PoketRupiah")

    local pocketList =
        poketRupiah
        and poketRupiah:FindFirstChild("PocketList")

    local balanceFrame =
        pocketList
        and pocketList:FindFirstChild("BalanceFrame")

    return
        balanceFrame
        and balanceFrame:FindFirstChild("Accumulated")

end


local function refreshSaldoDisplay()

    local label =
        getSaldoAccumulatedLabel()

    if not label then

        SaldoLabel.Text = "Rp -"

        return

    end


    local digits =
        (tostring(label.Text):gsub("%D", ""))

    if digits == "" then

        SaldoLabel.Text = "Rp -"

        return

    end


    SaldoLabel.Text =
        "Rp " .. formatWithCommas(digits)

end


task.spawn(function()

    while ScreenGui.Parent do

        pcall(refreshSaldoDisplay)

        task.wait(1)

    end

end)


--==========================================================
-- CHARACTER HELPER
--==========================================================

local function getCharacter()

    local character =
        player.Character

    if not character then

        character =
            player.CharacterAdded:Wait()

    end


    local hrp =
        character:WaitForChild(
            "HumanoidRootPart"
        )


    return character, hrp

end


--==========================================================
-- WRAP TO LOCATION
--
-- Memindahkan mobil (kalau player sedang mengemudi)
-- beserta player ke posisi tujuan, sambil tetap
-- mempertahankan posisi duduk player relatif
-- terhadap mobil.
--
-- Kalau player TIDAK sedang di dalam mobil,
-- cukup teleport player ke depan tujuan.
--==========================================================

local function wrapToLocation(
    targetCFrame,
    offsetZ
)

    offsetZ =
        offsetZ or -6

    local character, hrp =
        getCharacter()


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )


    local car =
        vehicles
        and
        vehicles:FindFirstChild(
            player.Name .. "sCar"
        )


    if car then

        --==================================================
        -- SIMPAN OFFSET PLAYER RELATIF TERHADAP MOBIL
        --==================================================

        local oldCarCFrame =
            car:GetPivot()


        local offset =
            oldCarCFrame:ToObjectSpace(
                hrp.CFrame
            )


        local newCarCFrame =
            targetCFrame *
            CFrame.new(
                0,
                0,
                offsetZ
            )


        --==================================================
        -- ANCHOR SEMENTARA
        --==================================================

        local anchoredParts = {}


        for _, part in ipairs(
            car:GetDescendants()
        ) do

            if part:IsA("BasePart") then

                table.insert(
                    anchoredParts,
                    {
                        part = part,
                        wasAnchored =
                            part.Anchored,
                    }
                )

                part.Anchored = true

            end

        end


        --==================================================
        -- WRAP (INTERPOLASI BERBASIS DURASI WAKTU)
        --==================================================

        local wrapDuration = 3


        local wrapStart =
            tick()


        while
            tick() - wrapStart < wrapDuration
        do

            local alpha =
                (tick() - wrapStart) /
                wrapDuration


            local stepCFrame =
                oldCarCFrame:Lerp(
                    newCarCFrame,
                    alpha
                )


            car:PivotTo(
                stepCFrame
            )


            hrp.CFrame =
                stepCFrame * offset


            task.wait(0.03)

        end


        --==================================================
        -- SNAP KE POSISI AKHIR
        --==================================================

        car:PivotTo(
            newCarCFrame
        )


        hrp.CFrame =
            newCarCFrame * offset


        --==================================================
        -- UNANCHOR KEMBALI
        --==================================================

        for _, entry in ipairs(
            anchoredParts
        ) do

            entry.part.Anchored =
                entry.wasAnchored

        end


    else

        --==================================================
        -- PLAYER TIDAK DI MOBIL, TELEPORT LANGSUNG
        --==================================================

        hrp.CFrame =
            targetCFrame *
            CFrame.new(
                0,
                0,
                offsetZ
            )

    end

end


--==========================================================
-- WRAP TO LOCATION (SOFT) — HOVER -> FREEZE -> TURUN PELAN
--
-- wrapToLocation asli Lerp LANGSUNG ke posisi akhir (garis
-- lurus 3D, termasuk komponen vertikal) dalam wrapDuration
-- detik. Itu bagus buat perpindahan jarak deket/rata, tapi
-- begitu dipakai buat "mendarat" dari jalur lurus (Y=1000)
-- ke titik parkir ATM (Y jauh lebih rendah), mobil efektif
-- meluncur turun dalam garis miring dalam waktu singkat lalu
-- nyentuh tanah masih dengan kecepatan Lerp yang tinggi --
-- itu penyebab mobil "mental"/nabrak begitu nyampe.
--
-- Fix-nya sama pola kayak teleportToStraightRoad: teleport
-- dulu ke ATAS titik tujuan (bukan Lerp lintas jarak jauh
-- yang miring), BEKU sebentar, baru turun PELAN murni
-- vertikal ke posisi final -- ga ada lagi momentum
-- horizontal+vertikal gede pas mobil sentuh platform.
--==========================================================

local function wrapToLocationSoft(
    targetCFrame,
    offsetZ
)

    offsetZ =
        offsetZ or -6

    local character, hrp =
        getCharacter()


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    local car =
        vehicles
        and
        vehicles:FindFirstChild(
            player.Name .. "sCar"
        )


    local finalCFrame =
        targetCFrame *
        CFrame.new(
            0,
            0,
            offsetZ
        )


    local HOVER_HEIGHT = 30

    local FREEZE_DURATION = 1.5

    local LOWER_DURATION = 1.5


    local hoverCFrame =
        finalCFrame +
        Vector3.new(0, HOVER_HEIGHT, 0)


    if not car then

        hrp.CFrame = hoverCFrame

        task.wait(FREEZE_DURATION)

        hrp.CFrame = finalCFrame

        return

    end


    --==================================================
    -- SIMPAN OFFSET PLAYER RELATIF TERHADAP MOBIL
    --==================================================

    local oldCarCFrame =
        car:GetPivot()

    local offset =
        oldCarCFrame:ToObjectSpace(
            hrp.CFrame
        )


    --==================================================
    -- ANCHOR SEMENTARA
    --
    -- AssemblyLinearVelocity/AssemblyAngularVelocity DI-
    -- NOL-KAN JUGA di sini, bukan cuma Anchored = true.
    -- Mobil ini abis ditarik scripted (wrapDriveStraightTo)
    -- sambil W ditahan terus & unanchored -- assembly-nya
    -- bisa nyimpen sisa velocity gede (dari wheel motor yang
    -- coba narik maju sementara posisi tiap frame di-override
    -- paksa). Anchoring doang TIDAK menghapus velocity yang
    -- udah kesimpen di part, cuma bikin dia ga kepakai
    -- SELAMA anchored -- begitu di-unanchor lagi di akhir
    -- fungsi, velocity lama itu balik aktif dan mobil
    -- "mental" walau posisinya udah didarat-in pelan-pelan.
    --==================================================

    local anchoredParts = {}

    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            table.insert(
                anchoredParts,
                {
                    part = part,
                    wasAnchored =
                        part.Anchored,
                }
            )

            part.Anchored = true

            part.AssemblyLinearVelocity =
                Vector3.new(0, 0, 0)

            part.AssemblyAngularVelocity =
                Vector3.new(0, 0, 0)

        end

    end


    --==================================================
    -- 1. NAIK KE POSISI HOVER (DI ATAS TUJUAN), BEKU
    --==================================================

    car:PivotTo(
        hoverCFrame
    )

    hrp.CFrame =
        hoverCFrame * offset


    task.wait(FREEZE_DURATION)


    --==================================================
    -- 2. TURUN PELAN-PELAN (LERP) SAMPAI NEMPEL TUJUAN
    --==================================================

    local lowerStart =
        tick()

    while
        tick() - lowerStart < LOWER_DURATION
    do

        local alpha =
            (tick() - lowerStart) /
            LOWER_DURATION

        local stepCFrame =
            hoverCFrame:Lerp(
                finalCFrame,
                alpha
            )

        car:PivotTo(
            stepCFrame
        )

        hrp.CFrame =
            stepCFrame * offset

        task.wait(0.03)

    end


    car:PivotTo(
        finalCFrame
    )

    hrp.CFrame =
        finalCFrame * offset


    --==================================================
    -- UNANCHOR KEMBALI
    --
    -- Nol-in velocity SEKALI LAGI tepat sebelum unanchor
    -- tiap part -- jaga-jaga kalau ada drift kecil selama
    -- fase anchored (harusnya ga ada, tapi murah buat
    -- dipastikan) supaya begitu fisik aktif lagi, mobil
    -- beneran diam total di titik parkir, bukan mental.
    --==================================================

    for _, entry in ipairs(
        anchoredParts
    ) do

        entry.part.AssemblyLinearVelocity =
            Vector3.new(0, 0, 0)

        entry.part.AssemblyAngularVelocity =
            Vector3.new(0, 0, 0)

        entry.part.Anchored =
            entry.wasAnchored

    end

end


--==========================================================
-- TELEPORT KE JALUR LURUS (HOVER -> FREEZE -> TURUN PELAN)
--
-- Teleport instan LANGSUNG ke atas permukaan jalur lurus
-- (persis di ujungnya) sempat bikin mobil "nabrak" -- fisik
-- mobil/chassis-nya kayak kaget begitu part barusan
-- di-stream/PivotTo, ban langsung nyodok ke aspal yang
-- belum sempat "settle". Fix-nya: teleport dulu ke atas
-- (HOVER_HEIGHT stud di atas permukaan), BEKU di situ
-- sebentar (biar part & fisiknya sempat kebentuk sempurna),
-- baru turun PELAN-PELAN (Lerp, bukan jatuh bebas) sampai
-- persis nempel ke jalur -- baru boleh gas.
--==========================================================

local function teleportToStraightRoad(
    startPos,
    lookAtPos
)

    local character, hrp =
        getCharacter()


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    local car =
        vehicles
        and vehicles:FindFirstChild(
            player.Name .. "sCar"
        )


    local HOVER_HEIGHT = 30

    local FREEZE_DURATION = 1.5

    local LOWER_DURATION = 1.5


    local hoverPos =
        startPos +
        Vector3.new(0, HOVER_HEIGHT, 0)

    local hoverCFrame =
        CFrame.new(
            hoverPos,
            hoverPos + (lookAtPos - startPos)
        )

    local groundCFrame =
        CFrame.new(
            startPos,
            lookAtPos
        )


    if not car then

        hrp.CFrame = hoverCFrame

        task.wait(FREEZE_DURATION)

        hrp.CFrame = groundCFrame

        return

    end


    --==================================================
    -- SIMPAN OFFSET PLAYER RELATIF TERHADAP MOBIL
    -- (sebelum mobil dipindah, sama kayak wrapToLocation)
    --==================================================

    local oldCarCFrame =
        car:GetPivot()

    local offset =
        oldCarCFrame:ToObjectSpace(
            hrp.CFrame
        )


    --==================================================
    -- ANCHOR SEMENTARA
    --==================================================

    local anchoredParts = {}

    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            table.insert(
                anchoredParts,
                {
                    part = part,
                    wasAnchored =
                        part.Anchored,
                }
            )

            part.Anchored = true

        end

    end


    --==================================================
    -- 1. NAIK KE POSISI HOVER, BEKU
    --==================================================

    car:PivotTo(
        hoverCFrame
    )

    hrp.CFrame =
        hoverCFrame * offset


    task.wait(FREEZE_DURATION)


    --==================================================
    -- 2. TURUN PELAN-PELAN (LERP) SAMPAI NEMPEL JALUR
    --==================================================

    local lowerStart =
        tick()

    while
        tick() - lowerStart < LOWER_DURATION
    do

        local alpha =
            (tick() - lowerStart) /
            LOWER_DURATION

        local stepCFrame =
            hoverCFrame:Lerp(
                groundCFrame,
                alpha
            )

        car:PivotTo(
            stepCFrame
        )

        hrp.CFrame =
            stepCFrame * offset

        task.wait(0.03)

    end


    car:PivotTo(
        groundCFrame
    )

    hrp.CFrame =
        groundCFrame * offset


    --==================================================
    -- UNANCHOR KEMBALI
    --==================================================

    for _, entry in ipairs(
        anchoredParts
    ) do

        entry.part.Anchored =
            entry.wasAnchored

    end

end


--==========================================================
-- DRIVE CAR TO (BENERAN NYETIR, BUKAN TELEPORT)
--
-- CFrame:Lerp (wrapToLocation) cuma pindah posisi, jadi
-- KM di dashboard mobil ga jalan. Fungsi ini beneran
-- nyetir pakai VehicleSeat.Throttle/.Steer menuju
-- targetPosition supaya jarak yang ditempuh itu nyata
-- (dan katanya gaji dihitung dari jarak asli).
--
-- Return true kalau berhasil sampai (dalam
-- arriveDistance), false kalau timeout/gagal — caller
-- sebaiknya fallback ke wrapToLocation supaya quest
-- ga stuck selamanya kalau mobil nyangkut.
--==========================================================

--==========================================================
-- KEY HOLD HELPERS
--
-- Chassis-nya ternyata BUKAN baca VehicleSeat.Throttle/
-- .Steer, tapi baca UserInputService key state beneran
-- (Controls.Throttle2="W", SteerLeft2="A", SteerRight2="D",
-- PBrake="P" -- toggle). Jadi kita simulasiin tekan/lepas
-- key asli pakai VirtualInputManager, bukan set property.
--==========================================================

local function tapKey(
    keyCode,
    holdTime
)

    holdTime =
        holdTime or 0.15


    VirtualInputManager:SendKeyEvent(
        true,
        keyCode,
        false,
        game
    )


    task.wait(holdTime)


    VirtualInputManager:SendKeyEvent(
        false,
        keyCode,
        false,
        game
    )

end


--==================================================
-- Value LIVE A-Chassis (PBrake, Gear, dll) ADANYA di
-- PlayerGui, BUKAN di workspace.Vehicles.<car> (yang
-- mana ga punya folder "Values" langsung sama sekali).
--==================================================

local function getChassisValue(
    valueName
)

    local chassisInterface =
        playerGui:FindFirstChild(
            "A-Chassis Interface"
        )

    if not chassisInterface then
        return nil
    end


    local values =
        chassisInterface:FindFirstChild(
            "Values"
        )

    return
        values
        and
        values:FindFirstChild(
            valueName
        )

end


--==================================================
-- PBrake yang BENERAN dibaca live sama sistem A-Chassis
-- ada di PlayerGui -- FindFirstChild ke tempat yang
-- salah (workspace.Vehicles.<car>.Values) selalu balik
-- nil, makanya fungsi ini SELAMA INI diam-diam ga
-- ngapa-ngapain, ga pernah beneran mencet P. Itu
-- penyebab mobil geter2 di tempat & RPM nanjak tapi
-- 0 KM/H pas di jalur lurus -- rem tangan ga pernah
-- kelepas.
--==================================================

local function releaseHandbrakeIfNeeded()

    local pbrakeValue =
        getChassisValue("PBrake")

    if not pbrakeValue then
        return
    end


    for attempt = 1, 3 do

        if not pbrakeValue.Value then
            break
        end


        tapKey(
            Enum.KeyCode.P,
            0.15
        )


        task.wait(0.3)

    end

end


--==================================================
-- KEBALIKAN DARI releaseHandbrakeIfNeeded() -- dipanggil
-- begitu mobil BARU SAJA berhenti di lantai deket ATM,
-- biar momentum sisa (mobil masih ngeglide dikit walau W
-- udah dilepas) ga bablas nabrak platform ATM. P itu
-- toggle, jadi dipencet berkali-kali sambil ngecek
-- PBrake.Value sampai kebaca true (nyala).
--==================================================

local function engageHandbrake()

    local pbrakeValue =
        getChassisValue("PBrake")

    if not pbrakeValue then
        return
    end


    for attempt = 1, 3 do

        if pbrakeValue.Value then
            break
        end


        tapKey(
            Enum.KeyCode.P,
            0.15
        )


        task.wait(0.3)

    end

end


--==================================================
-- Gear = 0 itu Netral -- rem tangan udah kelepas tapi
-- kalau masih Netral, W ga bakal narik mobil kemana-
-- mana (RPM naik dikit doang di idle, KM/H tetep 0).
-- Tekan "E" (Controls.ShiftUp) buat pindah ke gigi maju.
--==================================================

local function ensureForwardGearEngaged()

    local gearValue =
        getChassisValue("Gear")

    if not gearValue then
        return
    end


    for attempt = 1, 3 do

        if gearValue.Value > 0 then
            break
        end


        tapKey(
            Enum.KeyCode.E,
            0.15
        )


        task.wait(0.3)

    end

end


--==================================================
-- Pindahin transmisi ke "S" (Sport). Controls cuma
-- punya "ToggleTransMode" ("M") -- TOGGLE, bukan set
-- langsung, jadi dipencet berkali-kali sambil ngecek
-- sampai kebaca "S".
--
-- Values.TransmissionMode ("AutoD" dkk) BUKAN indikator
-- yang bener buat dicek -- itu nama mode transmisi
-- internal, bukan posisi selektor yang keliatan di
-- speedometer (N/D/S/ST/R/dst). Yang bener dibaca teks
-- yang BENERAN ditampilkan ke player --
-- PlayerGui["A-Chassis Interface"].Speedo.Speedo1.Main.
-- Transmission (TextLabel) -- begitu .Text == "S", stop.
--==================================================

local SPORT_TRANSMISSION_MODE = "S"


local function getTransmissionDisplayLabel()

    local chassisInterface =
        playerGui:FindFirstChild(
            "A-Chassis Interface"
        )

    if not chassisInterface then
        return nil
    end


    local speedo =
        chassisInterface:FindFirstChild(
            "Speedo"
        )

    if not speedo then
        return nil
    end


    local speedo1 =
        speedo:FindFirstChild(
            "Speedo1"
        )

    if not speedo1 then
        return nil
    end


    local main =
        speedo1:FindFirstChild(
            "Main"
        )

    if not main then
        return nil
    end


    return main:FindFirstChild(
        "Transmission"
    )

end


local function ensureSportTransmissionMode()

    local transmissionLabel =
        getTransmissionDisplayLabel()

    if not transmissionLabel then
        return
    end


    for attempt = 1, 5 do

        if
            transmissionLabel.Text ==
            SPORT_TRANSMISSION_MODE
        then

            break

        end


        tapKey(
            Enum.KeyCode.M,
            0.15
        )


        task.wait(0.3)

    end

end


--==================================================
-- Dipanggil BERKALA (bukan cuma sekali di awal nyetir)
-- selama drive jalur lurus berlangsung -- rem tangan/
-- gigi/mode bisa aja balik ke kondisi ga siap di TENGAH
-- jalan (misal auto trans-brake nyala pas mobil sempat
-- diam sebentar karena physics jitter), dan kalau cuma
-- dicek sekali di awal, itu ga akan ketangkep -- mobil
-- keliatan "tiba-tiba berhenti di tengah jalan" padahal
-- W masih ketahan terus. Ngecek ulang tiap
-- MAINTENANCE_INTERVAL detik biar self-heal.
--==================================================

local function performDriveMaintenance()

    releaseHandbrakeIfNeeded()

    ensureForwardGearEngaged()

    ensureSportTransmissionMode()

end


local function driveCarTo(
    targetPosition,
    arriveDistance,
    timeoutSeconds
)

    arriveDistance =
        arriveDistance or 8

    timeoutSeconds =
        timeoutSeconds or 45


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    local car =
        vehicles
        and
        vehicles:FindFirstChild(
            player.Name .. "sCar"
        )

    if not car then
        return false
    end


    performDriveMaintenance()


    local throttleKey =
        Enum.KeyCode.W

    local leftKey =
        Enum.KeyCode.A

    local rightKey =
        Enum.KeyCode.D


    local throttleDown = false

    local leftDown = false

    local rightDown = false


    local function setThrottle(
        down
    )

        if down == throttleDown then
            return
        end

        throttleDown = down

        VirtualInputManager:SendKeyEvent(
            down,
            throttleKey,
            false,
            game
        )

    end


    local function setSteer(
        direction
    )

        local wantLeft =
            direction < 0

        local wantRight =
            direction > 0


        if wantLeft ~= leftDown then

            leftDown = wantLeft

            VirtualInputManager:SendKeyEvent(
                leftDown,
                leftKey,
                false,
                game
            )

        end


        if wantRight ~= rightDown then

            rightDown = wantRight

            VirtualInputManager:SendKeyEvent(
                rightDown,
                rightKey,
                false,
                game
            )

        end

    end


    local driveStart =
        tick()

    local reached = false

    local lastMaintenanceCheck =
        tick()

    local MAINTENANCE_INTERVAL = 2


    while
        autoRunning
        and
        tick() - driveStart < timeoutSeconds
    do

        if not ScreenGui.Parent then
            break
        end


        if
            tick() - lastMaintenanceCheck >
            MAINTENANCE_INTERVAL
        then

            lastMaintenanceCheck =
                tick()

            performDriveMaintenance()

        end


        local carCFrame =
            car:GetPivot()

        local toTarget =
            targetPosition -
            carCFrame.Position

        local flatToTarget =
            Vector3.new(
                toTarget.X,
                0,
                toTarget.Z
            )

        local distance =
            flatToTarget.Magnitude


        if distance <= arriveDistance then

            reached = true

            break

        end


        local localDir =
            carCFrame:VectorToObjectSpace(
                flatToTarget.Unit
            )

        local angle =
            math.deg(
                math.atan2(
                    localDir.X,
                    -localDir.Z
                )
            )


        Status.Text =
            "Status: [7] Nyetir... jarak " ..
            string.format(
                "%.0f",
                distance
            ) ..
            " studs"


        if angle > 8 then

            setSteer(1)

        elseif angle < -8 then

            setSteer(-1)

        else

            setSteer(0)

        end


        setThrottle(true)


        task.wait()

    end


    setThrottle(false)

    setSteer(0)


    return reached

end


--==========================================================
-- DRIVE STRAIGHT TO (JALUR LURUS, IKUT GARIS TENGAH)
--
-- Percobaan pertama (steer ke arah ujung jauh, kayak
-- driveCarTo) geter2 -- sudutnya nyaris ga berubah biarpun
-- udah melenceng lumayan jauh dari garis (soalnya ujungnya
-- 10rb stud jauhnya), jadi koreksinya lemot & gampang
-- ke-toggle bolak-balik pas nyentuh ambang batas.
--
-- Percobaan kedua (GA ADA steering sama sekali) malah
-- kebalikannya -- sedikit aja mobilnya ga pas lurus dari
-- awal (fisik abis teleport ga akan PERSIS 0.000 derajat),
-- itu ngendap terus tanpa koreksi apa pun sepanjang 10rb
-- stud sampai akhirnya keluar dari jalur (lebar cuma 24
-- stud) dan jatuh.
--
-- Fix yang bener: "pure pursuit" -- bidik ke titik yang
-- ADA DI GARIS TENGAH, LOOKAHEAD_DISTANCE stud DI DEPAN
-- posisi mobil sekarang (proyeksi posisi mobil ke garis
-- lineStart->lineEnd) -- BUKAN ke ujung jauh. Kalau mobil
-- melenceng ke samping, titik incar ini otomatis narik
-- balik ke tengah (makin jauh melenceng, makin besar sudut
-- koreksinya), dan mengecil ke 0 begitu udah balik ke
-- tengah -- respons cepat tapi tetep halus/stabil.
--==========================================================

--==========================================================
-- FREEZE CAR IN PLACE (INSTA STOP, BUKAN NUNGGU REM FISIK)
--
-- engageHandbrake() butuh sampai 3x tapKey (tiap tap diikuti
-- task.wait(0.3)) sebelum PBrake.Value beneran kebaca true --
-- itu jendela hampir 1 detik dimana mobil (apalagi yang
-- gede/berat) masih bisa ngeglide dari momentum sisa dan
-- ttp nyodok/nabrak platform ATM walau udah "dianggap
-- sampai". Freeze ini setara teleport -- nol-in velocity +
-- Anchored = true SEKETIKA, mobil berhenti total persis di
-- posisi itu juga, ga ada jendela waktu buat ngeglide sama
-- sekali. Dipanggil TEPAT begitu distanceToEnd masuk radius
-- arrive (di dalam driveStraightTo), bukan nunggu loop
-- drive-nya kelar dulu baru direm.
--==========================================================

local function freezeCarInPlace(
    car
)

    if not car then
        return
    end

    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            part.AssemblyLinearVelocity =
                Vector3.new(0, 0, 0)

            part.AssemblyAngularVelocity =
                Vector3.new(0, 0, 0)

            part.Anchored = true

        end

    end

end


--==========================================================
-- UNFREEZE CAR (LEPAS ANCHOR SETELAH BENERAN BERHENTI)
--
-- freezeCarInPlace() bikin mobil Anchored = true SEKETIKA
-- pas nyampe deket ATM, biar ga ada jendela glide buat
-- nabrak platform. Tapi kalau Anchored ini DIBIARIN terus
-- selama Step 8-10 (keluar mobil, jalan ke bagasi, hold
-- AmbilPrompt buat ambil koper), mobil jadi "beku" nempel di
-- physics -- ProximityPrompt/hold-nya bisa gagal ke-detect
-- konsisten karena state fisik mobil ga pernah balik normal
-- (BasePart yang Anchored ga nge-fire event fisik yang sama
-- kayak part biasa, dan A-Chassis-nya sendiri mungkin ga
-- expect part tetap Anchored lama-lama). Begitu udah beneran
-- berhenti (velocity 0, Anchored), langsung dilepas lagi
-- (Anchored = false) -- mobil TETAP DIAM di tempat (velocity
-- udah 0, ga ada W/gas lagi) tapi fisiknya balik normal buat
-- interaksi Step 8-10 selanjutnya.
--==========================================================

local function unfreezeCarInPlace(
    car
)

    if not car then
        return
    end

    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            part.Anchored = false

        end

    end

end


local function driveStraightTo(
    lineStart,
    lineEnd,
    arriveDistance,
    timeoutSeconds
)

    arriveDistance =
        arriveDistance or 8

    timeoutSeconds =
        timeoutSeconds or 45


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    local car =
        vehicles
        and
        vehicles:FindFirstChild(
            player.Name .. "sCar"
        )

    if not car then
        return false
    end


    --==================================================
    -- PASTIKAN UNANCHORED SEBELUM MULAI NYETIR
    --
    -- Kalau putaran sebelumnya berakhir dengan
    -- freezeCarInPlace() (Anchored = true), mobil ga akan
    -- bisa gerak sama sekali biarpun W ditahan -- makanya
    -- di-unanchor paksa di sini dulu, di awal SETIAP
    -- panggilan driveStraightTo, apapun kondisi sebelumnya.
    --==================================================

    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            part.Anchored = false

        end

    end


    performDriveMaintenance()


    local throttleKey =
        Enum.KeyCode.W

    local leftKey =
        Enum.KeyCode.A

    local rightKey =
        Enum.KeyCode.D


    local leftDown = false

    local rightDown = false


    local function setSteer(
        direction
    )

        local wantLeft =
            direction < 0

        local wantRight =
            direction > 0


        if wantLeft ~= leftDown then

            leftDown = wantLeft

            VirtualInputManager:SendKeyEvent(
                leftDown,
                leftKey,
                false,
                game
            )

        end


        if wantRight ~= rightDown then

            rightDown = wantRight

            VirtualInputManager:SendKeyEvent(
                rightDown,
                rightKey,
                false,
                game
            )

        end

    end


    local fullLine =
        lineEnd - lineStart

    local lineLength =
        fullLine.Magnitude

    local lineDir =
        fullLine.Unit


    --==================================================
    -- SEMUA ANGKA STEER DI BAWAH INI DIGEDEIN BANGET --
    -- awalnya dituning buat jalur SEMPIT (24 stud) yang
    -- perlu presisi biar ga jatuh dari pinggir. Sekarang
    -- di LANTAI KOTAK yang raksasa, presisi kayak gitu ga
    -- perlu sama sekali -- user bilang "belok dikit gapapa,
    -- yang penting sampe tujuan". Mobil (apalagi yang gede
    -- kayak truk/bus courier ini) putar arahnya LAMBAT --
    -- steer yang galak/deadzone sempit bikin fisiknya ga
    -- sempat ngikutin sebelum arah steer udah keburu
    -- di-flip lagi -> itu penyebab "kanan kiri kanan kiri"
    -- sampe speednya ngedrop ke 0. Dengan angka-angka yang
    -- jauh lebih longgar ini, koreksi jadi jarang & pelan --
    -- mobil boleh ngambang agak jauh dari garis lurus
    -- idealnya, tapi jalan TERUS tanpa geter, dan tetep
    -- nyampe (arriveDistance dicek dari jarak LANGSUNG ke
    -- titik tujuan, bukan dari seberapa presisi nempel
    -- garis).
    --==================================================

    local LOOKAHEAD_DISTANCE = 400

    local STEER_DEADZONE = 20

    local STEER_COMMIT_DURATION = 1

    local steerDirection = 0

    local lastSteerChangeTime = 0


    --==================================================
    -- STUCK DETECTOR -- ngecek progress jarak tiap
    -- STUCK_CHECK_INTERVAL detik. Kalau majunya kurang dari
    -- STUCK_PROGRESS_THRESHOLD stud (padahal W ketahan
    -- gaspol terus), berarti mobil BENERAN kesangkut/mentok
    -- sesuatu (bukan cuma lagi belok landai) -- lepas gas +
    -- steer TAJAM ke satu arah sebentar (STUCK_NUDGE_
    -- DURATION) buat coba geser badan mobil lepas dari yang
    -- ngeganjel, baru lanjut gaspol lurus lagi kayak biasa.
    -- Ini SATU-SATUNYA momen throttle dilepas selain pas
    -- beneran sampai/timeout -- di luar itu W selalu ketahan
    -- gaspol penuh (sesuai permintaan: "selama blm ketitik
    -- parkir gaspol terus").
    --==================================================

    local STUCK_CHECK_INTERVAL = 2

    local STUCK_PROGRESS_THRESHOLD = 15

    local STUCK_NUDGE_DURATION = 0.6

    local lastStuckCheckTime = tick()

    local lastStuckCheckPos = car:GetPivot().Position


    VirtualInputManager:SendKeyEvent(
        true,
        throttleKey,
        false,
        game
    )


    local driveStart =
        tick()

    local reached = false

    local lastMaintenanceCheck =
        tick()

    local MAINTENANCE_INTERVAL = 2


    while
        autoRunning
        and
        tick() - driveStart < timeoutSeconds
    do

        if not ScreenGui.Parent then
            break
        end


        if
            tick() - lastMaintenanceCheck >
            MAINTENANCE_INTERVAL
        then

            lastMaintenanceCheck =
                tick()

            performDriveMaintenance()

        end


        local carCFrame =
            car:GetPivot()

        local carPos =
            carCFrame.Position


        local toEnd =
            lineEnd - carPos

        local flatToEnd =
            Vector3.new(
                toEnd.X,
                0,
                toEnd.Z
            )

        local distanceToEnd =
            flatToEnd.Magnitude


        if distanceToEnd <= arriveDistance then

            freezeCarInPlace(car)

            reached = true

            break

        end


        --==================================================
        -- STUCK CHECK -- jalan duluan sebelum steering biasa,
        -- biar kalau kedeteksi kesangkut, nudge-nya ga
        -- ketimpa langsung sama steer normal di bawah.
        --==================================================

        if
            tick() - lastStuckCheckTime >=
            STUCK_CHECK_INTERVAL
        then

            local progressed =
                (carPos - lastStuckCheckPos).Magnitude

            if progressed < STUCK_PROGRESS_THRESHOLD then

                Status.Text =
                    "Status: [7] Kesangkut, geser dikit..."

                --==========================================
                -- Lepas gas sebentar + banting steer TAJAM
                -- ke arah KEBALIKAN dari arah steer terakhir
                -- (kalau belum pernah nge-steer, default ke
                -- kanan) -- coba geser badan mobil lepas dari
                -- yang ngeganjel.
                --==========================================

                VirtualInputManager:SendKeyEvent(
                    false,
                    throttleKey,
                    false,
                    game
                )

                local nudgeDirection =
                    steerDirection ~= 0
                    and -steerDirection
                    or 1

                setSteer(nudgeDirection)

                task.wait(STUCK_NUDGE_DURATION)

                setSteer(0)

                VirtualInputManager:SendKeyEvent(
                    true,
                    throttleKey,
                    false,
                    game
                )

                steerDirection = 0

                lastSteerChangeTime =
                    tick()

            end


            lastStuckCheckTime =
                tick()

            lastStuckCheckPos =
                carPos

        end


        --==================================================
        -- PROYEKSI posisi mobil ke garis, ambil titik
        -- LOOKAHEAD_DISTANCE stud di depannya (di-clamp
        -- biar ga ngelewatin ujung jalur).
        --==================================================

        local alongDistance =
            (carPos - lineStart):Dot(
                lineDir
            )

        local lookaheadAlong =
            math.clamp(
                alongDistance + LOOKAHEAD_DISTANCE,
                0,
                lineLength
            )

        local lookaheadPoint =
            lineStart +
            lineDir * lookaheadAlong


        local toLookahead =
            lookaheadPoint - carPos

        local flatToLookahead =
            Vector3.new(
                toLookahead.X,
                0,
                toLookahead.Z
            )


        if flatToLookahead.Magnitude > 0.5 then

            local localDir =
                carCFrame:VectorToObjectSpace(
                    flatToLookahead.Unit
                )

            local angle =
                math.deg(
                    math.atan2(
                        localDir.X,
                        -localDir.Z
                    )
                )


            local wantDirection = 0

            if angle > STEER_DEADZONE then

                wantDirection = 1

            elseif angle < -STEER_DEADZONE then

                wantDirection = -1

            end


            if
                wantDirection ~= steerDirection
                and
                (tick() - lastSteerChangeTime) >=
                    STEER_COMMIT_DURATION
            then

                steerDirection = wantDirection

                lastSteerChangeTime = tick()

            end


            setSteer(steerDirection)

        end


        Status.Text =
            "Status: [7] Nyetir di lantai... jarak " ..
            string.format(
                "%.0f",
                distanceToEnd
            ) ..
            " studs"


        task.wait()

    end


    VirtualInputManager:SendKeyEvent(
        false,
        throttleKey,
        false,
        game
    )

    setSteer(0)


    return reached

end


--==========================================================
-- WRAP DRIVE STRAIGHT TO (TARIK CFRAME, BAN TETEP MUTER)
--
-- driveStraightTo (fisik beneran, setir pure-pursuit) udah
-- jalan tapi lambat & rawan macet di tengah (rem tangan/
-- gigi balik netral, dsb, walaupun udah ada self-heal).
-- User minta alternatif yang lebih presisi/cepat/soft:
-- BAN TETEP MUTER (W ditahan terus -> RPM naik, roda tetap
-- keliatan jalan) TAPI badan mobil ditarik LANGSUNG lewat
-- CFrame di garis 100% lurus dengan kecepatan tetap
-- (default 400 stud/detik) -- ga pernah mencong (garisnya
-- exact, bukan hasil setir), ga pernah macet nunggu fisik
-- akselerasi dari 0/nyangkut netral, sampainya presisi.
--
-- Mobil SENGAJA TIDAK dianchor (beda dari wrapToLocation/
-- teleportToStraightRoad) -- kalau dianchor, physics-nya
-- mati total & roda ga akan muter walau W ditahan. Body-nya
-- di-PivotTo tiap frame (override posisi), tapi wheel
-- constraint & motor AutoD tetap simulasi jalan sendiri di
-- belakang layar buat efek visual "ban jalan".
--==========================================================

local function wrapDriveStraightTo(
    lineStart,
    lineEnd,
    speed,
    arriveDistance
)

    speed =
        speed or 50

    arriveDistance =
        arriveDistance or 15


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    local car =
        vehicles
        and
        vehicles:FindFirstChild(
            player.Name .. "sCar"
        )

    if not car then
        return false
    end


    local character, hrp =
        getCharacter()


    local lineDir =
        (lineEnd - lineStart).Unit


    --==================================================
    -- PASTIKAN UNANCHORED SEBELUM MULAI (sama kayak
    -- driveStraightTo) -- kalau putaran sebelumnya berakhir
    -- dengan freezeCarInPlace() (Anchored = true), PivotTo
    -- di bawah masih akan "berhasil" motong posisi (anchored
    -- part tetap bisa di-PivotTo), TAPI wheel constraint-nya
    -- ga akan muter sama sekali walau W ditahan -- ban
    -- keliatan diem/nge-drag kayak balok. Unanchor paksa dulu
    -- di sini biar efek visual "ban jalan" tetap kepenuhi.
    --==================================================

    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            part.Anchored = false

        end

    end


    performDriveMaintenance()


    --==================================================
    -- TAHAN W TERUS -- roda tetap "jalan" (RPM naik,
    -- animasi/rotasi wheel tetap muter) walaupun posisi
    -- mobil ditarik scripted, bukan didorong wheel force.
    --==================================================

    VirtualInputManager:SendKeyEvent(
        true,
        Enum.KeyCode.W,
        false,
        game
    )


    local lastStep =
        tick()

    local reached = false


    while
        autoRunning
    do

        if not ScreenGui.Parent then
            break
        end


        --==================================================
        -- MAINTENANCE TIAP FRAME, BUKAN TIAP 2 DETIK
        --
        -- User laporan mobil "kadang masih berhenti2" pas
        -- ditarik wrap -- releaseHandbrakeIfNeeded/
        -- ensureForwardGearEngaged/ensureSportTransmissionMode
        -- semuanya cuma BACA Value dulu & langsung break tanpa
        -- nunggu kalau kondisinya udah bener (murah dipanggil
        -- tiap frame), tapi kalau sempat kepicu balik (misal
        -- PBrake ke-toggle balik true sesaat oleh sistem
        -- A-Chassis-nya sendiri), gate 2 detik sebelumnya
        -- bikin ada jendela sampai 2 detik dimana mobil
        -- keliatan "diem" sebelum ke-fix. Dicek tiap frame di
        -- sini biar koreksi instan, ga ada jendela diem lagi.
        --==================================================

        performDriveMaintenance()


        local now =
            tick()

        local dt =
            now - lastStep

        lastStep = now


        local carCFrame =
            car:GetPivot()

        local carPos =
            carCFrame.Position


        local toEnd =
            lineEnd - carPos

        local flatToEnd =
            Vector3.new(
                toEnd.X,
                0,
                toEnd.Z
            )

        local distanceToEnd =
            flatToEnd.Magnitude


        if distanceToEnd <= arriveDistance then

            freezeCarInPlace(car)

            reached = true

            break

        end


        --==================================================
        -- OFFSET PLAYER RELATIF TERHADAP MOBIL, DIAMBIL
        -- ULANG TIAP FRAME (bukan sekali di awal) -- mobil
        -- TIDAK dianchor, jadi player bisa geser dikit dari
        -- posisi duduk fisiknya tiap frame kalau dipakai
        -- offset basi.
        --==================================================

        local offset =
            carCFrame:ToObjectSpace(
                hrp.CFrame
            )


        local moveDistance =
            math.min(
                speed * dt,
                distanceToEnd
            )


        local newPos =
            carPos +
            lineDir * moveDistance

        local newCFrame =
            CFrame.new(
                newPos,
                newPos + lineDir
            )


        car:PivotTo(
            newCFrame
        )

        hrp.CFrame =
            newCFrame * offset


        --==================================================
        -- SAMAIN VELOCITY FISIK SAMA ARAH TARIKAN
        --
        -- Mobil TIDAK dianchor (biar roda tetap muter), jadi
        -- di ANTARA dua panggilan PivotTo ini, physics engine
        -- (gravity, suspension, wheel constraint) tetap jalan
        -- sendiri berdasarkan velocity part yang KEBETULAN
        -- ketinggalan dari drive/wrap sebelumnya (bisa 0, bisa
        -- ke arah lain) -- itu bikin badan mobil kekejar/
        -- ketarik balik dikit tiap step fisika sebelum
        -- di-snap maju lagi sama PivotTo, KELIATAN kayak
        -- "berhenti sebentar-sebentar" walau jarak di Status
        -- tetap berkurang terus. Nge-set velocity part SAMA
        -- persis arah & besar tarikan (lineDir * speed) tiap
        -- frame bikin physics-nya "setuju" sama arah gerak
        -- yang dipaksakan -- ga ada lagi tarik-menarik antara
        -- override script vs sisa momentum lama.
        --==================================================

        local travelVelocity =
            lineDir * speed

        for _, part in ipairs(
            car:GetDescendants()
        ) do

            if part:IsA("BasePart") then

                part.AssemblyLinearVelocity =
                    travelVelocity

                part.AssemblyAngularVelocity =
                    Vector3.new(0, 0, 0)

            end

        end


        Status.Text =
            "Status: [7] Ditarik di lantai (" ..
            tostring(speed) ..
            " stud/s)... jarak " ..
            string.format(
                "%.0f",
                distanceToEnd
            ) ..
            " studs"


        task.wait()

    end


    VirtualInputManager:SendKeyEvent(
        false,
        Enum.KeyCode.W,
        false,
        game
    )


    return reached

end


--==========================================================
-- DRIVE STRAIGHT TO + WRAP ASSIST (GASPOL TERUS -- WRAP
-- CUMA NUTUPIN PAS MULAI LAMBAT, BUKAN NGE-CAP KECEPATAN)
--
-- wrapDriveStraightTo (di atas) MEMAKSA posisi mobil geser
-- SAMA PERSIS sebesar speed*dt TIAP FRAME -- itu jadi
-- KECEPATAN MOBIL KE-CAP HABIS di angka speed itu (misal
-- WRAP_SPEED=120), walau fisik aslinya (kalau dibiarin
-- gaspol beneran di jalur lurus/mulus) bisa lari lebih
-- kenceng dari itu. User MINTA mobil TETAP GASPOL PENUH
-- lewat fisik ASLI (W ditahan terus + setir pure-pursuit,
-- SAMA PERSIS kayak driveStraightTo) -- wrap di sini CUMA
-- turun tangan kalau progress AKTUAL (jarak maju beneran
-- sejak frame sebelumnya) JATUH DI BAWAH ambang
-- wrapAssistMinSpeed -- entah karena kena gundukan, dikit
-- nyangkut, lambat akselerasi, dsb -- buat NUTUPIN
-- KEKURANGANNYA doang (top-up posisi maju sebesar
-- selisihnya, rotasi mobil TETAP dipertahankan persis apa
-- adanya dari steer, ga di-reset). Kalau fisik lagi kenceng
-- (progress >= ambang), wrap SAMA SEKALI ga ngapa-ngapain --
-- GA ADA cap kecepatan atas sama sekali.
--==========================================================

local function driveStraightToWrapAssist(
    lineStart,
    lineEnd,
    arriveDistance,
    timeoutSeconds,
    wrapAssistMinSpeed
)

    arriveDistance =
        arriveDistance or 8

    timeoutSeconds =
        timeoutSeconds or 45

    wrapAssistMinSpeed =
        wrapAssistMinSpeed or 120


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    local car =
        vehicles
        and
        vehicles:FindFirstChild(
            player.Name .. "sCar"
        )

    if not car then
        return false
    end


    local character, hrp =
        getCharacter()


    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            part.Anchored = false

        end

    end


    performDriveMaintenance()


    local throttleKey =
        Enum.KeyCode.W

    local leftKey =
        Enum.KeyCode.A

    local rightKey =
        Enum.KeyCode.D


    local leftDown = false

    local rightDown = false


    local function setSteer(
        direction
    )

        local wantLeft =
            direction < 0

        local wantRight =
            direction > 0


        if wantLeft ~= leftDown then

            leftDown = wantLeft

            VirtualInputManager:SendKeyEvent(
                leftDown,
                leftKey,
                false,
                game
            )

        end


        if wantRight ~= rightDown then

            rightDown = wantRight

            VirtualInputManager:SendKeyEvent(
                rightDown,
                rightKey,
                false,
                game
            )

        end

    end


    local fullLine =
        lineEnd - lineStart

    local lineLength =
        fullLine.Magnitude

    local lineDir =
        fullLine.Unit


    local LOOKAHEAD_DISTANCE = 400

    local STEER_DEADZONE = 20

    local STEER_COMMIT_DURATION = 1

    local steerDirection = 0

    local lastSteerChangeTime = 0


    --==================================================
    -- GASPOL TERUS -- SATU KALI DITEKAN DI AWAL, GA
    -- PERNAH DILEPAS SAMPAI SAMPAI/TIMEOUT (beda dari
    -- driveStraightTo yang punya stuck-nudge yang sempat
    -- lepas gas -- di sini ga perlu, karena wrap assist di
    -- bawah UDAH otomatis nutupin kalau progress kurang,
    -- termasuk kasus "nyangkut").
    --==================================================

    VirtualInputManager:SendKeyEvent(
        true,
        throttleKey,
        false,
        game
    )


    local driveStart =
        tick()

    local reached = false

    local lastMaintenanceCheck =
        tick()

    local MAINTENANCE_INTERVAL = 2

    local lastStep =
        tick()

    local lastPos =
        car:GetPivot().Position


    while
        autoRunning
        and
        tick() - driveStart < timeoutSeconds
    do

        if not ScreenGui.Parent then
            break
        end


        if
            tick() - lastMaintenanceCheck >
            MAINTENANCE_INTERVAL
        then

            lastMaintenanceCheck =
                tick()

            performDriveMaintenance()

        end


        local now =
            tick()

        local dt =
            now - lastStep

        lastStep = now


        local carCFrame =
            car:GetPivot()

        local carPos =
            carCFrame.Position


        --==================================================
        -- WRAP ASSIST -- progressAlong ngukur seberapa jauh
        -- mobil BENERAN maju (proyeksi ke arah garis) sejak
        -- posisi yang dicatat di frame sebelumnya. Kalau
        -- kurang dari minProgress (ambang minimum buat
        -- durasi frame ini), tempel selisihnya (shortfall)
        -- ke posisi -- rotasi carCFrame TETAP sama persis,
        -- cuma translasi posisinya yang ditambah.
        --==================================================

        local progressAlong =
            (carPos - lastPos):Dot(
                lineDir
            )

        --==================================================
        -- CLAMP dt BUAT MINPROGRESS -- kalau frame sebelumnya
        -- sempat ke-jeda lama (misal performDriveMaintenance
        -- lagi nyoba fix PBrake/Gear/Transmission, tiap
        -- attempt-nya ada task.wait(0.3), bisa nambah dt
        -- sampai 1-2 detik), minProgress = wrapAssistMinSpeed
        -- * dt bisa jadi RATUSAN stud dalam SATU frame kalau
        -- ga di-clamp -- itu bikin mobil "ngelempar" dirinya
        -- sendiri jauh ke depan sekali gerak (bisa nembus
        -- lewat/nyangkut di platform ATM pas lagi deket-deket
        -- radius arrive, keliatan cacat/patah-patah pas mau
        -- berhenti). Di-clamp ke dt maksimum 0.1 detik dulu
        -- SEBELUM dipakai ngitung minProgress -- assist tetap
        -- jalan, tapi ga akan pernah ngelempar lebih dari
        -- wrapAssistMinSpeed*0.1 stud dalam satu frame.
        --==================================================

        local dtForAssist =
            math.min(dt, 0.1)

        local minProgress =
            wrapAssistMinSpeed * dtForAssist

        if progressAlong < minProgress then

            local shortfall =
                minProgress - progressAlong

            local offset =
                carCFrame:ToObjectSpace(
                    hrp.CFrame
                )

            local newPos =
                carPos +
                lineDir * shortfall

            local newCFrame =
                CFrame.new(
                    newPos - carPos
                ) * carCFrame

            car:PivotTo(
                newCFrame
            )

            hrp.CFrame =
                newCFrame * offset

            carCFrame = newCFrame

            carPos = newCFrame.Position

        end


        lastPos =
            carPos


        local toEnd =
            lineEnd - carPos

        local flatToEnd =
            Vector3.new(
                toEnd.X,
                0,
                toEnd.Z
            )

        local distanceToEnd =
            flatToEnd.Magnitude


        if distanceToEnd <= arriveDistance then

            freezeCarInPlace(car)

            reached = true

            break

        end


        --==================================================
        -- STEERING PURE-PURSUIT -- persis pola yang sama
        -- kayak driveStraightTo.
        --==================================================

        local alongDistance =
            (carPos - lineStart):Dot(
                lineDir
            )

        local lookaheadAlong =
            math.clamp(
                alongDistance + LOOKAHEAD_DISTANCE,
                0,
                lineLength
            )

        local lookaheadPoint =
            lineStart +
            lineDir * lookaheadAlong


        local toLookahead =
            lookaheadPoint - carPos

        local flatToLookahead =
            Vector3.new(
                toLookahead.X,
                0,
                toLookahead.Z
            )


        if flatToLookahead.Magnitude > 0.5 then

            local localDir =
                carCFrame:VectorToObjectSpace(
                    flatToLookahead.Unit
                )

            local angle =
                math.deg(
                    math.atan2(
                        localDir.X,
                        -localDir.Z
                    )
                )


            local wantDirection = 0

            if angle > STEER_DEADZONE then

                wantDirection = 1

            elseif angle < -STEER_DEADZONE then

                wantDirection = -1

            end


            if
                wantDirection ~= steerDirection
                and
                (tick() - lastSteerChangeTime) >=
                    STEER_COMMIT_DURATION
            then

                steerDirection = wantDirection

                lastSteerChangeTime = tick()

            end


            setSteer(steerDirection)

        end


        Status.Text =
            "Status: [7] Gaspol (wrap assist kalo lambat)... jarak " ..
            string.format(
                "%.0f",
                distanceToEnd
            ) ..
            " studs"


        task.wait()

    end


    VirtualInputManager:SendKeyEvent(
        false,
        throttleKey,
        false,
        game
    )

    setSteer(0)


    return reached

end


--==========================================================
-- WRAP DRIVE TIMED TO (CFRAME-DRAG MURNI, KECEPATAN
-- DIHITUNG DARI TARGET WAKTU TEMPUH -- BUKAN ANGKA STUD/
-- DETIK TETAP)
--
-- User curiga progress/gaji dihitung berdasarkan WAKTU
-- tempuh, bukan jarak fisik yang ditempuh -- kalau bener,
-- ga perlu lagi nyetir fisik/wrap-assist yang rumit, cukup
-- CFrame-drag MURNI (sama kayak wrapDriveStraightTo, W
-- ditahan terus biar RPM/roda tetap keliatan jalan, TAPI
-- badan mobil di-PivotTo tiap frame) -- bedanya, speed-nya
-- BUKAN angka tetap yang di-ketik manual, tapi DIHITUNG
-- OTOMATIS dari travelDistance/desiredSeconds. Karena tiap
-- ATM jaraknya beda-beda (random), pakai speed TETAP bikin
-- waktu tempuhnya beda-beda tiap kali -- dengan speed
-- dihitung dari jarak/waktu, mobil SELALU nyampe dalam
-- kira-kira desiredSeconds detik, ATM manapun jaraknya.
--
-- desiredSeconds diambil dari wrapTravelTimeSeconds (GUI
-- TextBox "Target waktu tempuh") biar bisa dicoba-coba cari
-- angka yang pas tanpa edit script. TimerLabel di-update
-- REALTIME tiap frame biar user bisa liat langsung di GUI
-- berapa detik yang udah lewat buat cross-check.
--
-- freezeCarInPlace() tetap dipanggil begitu masuk radius
-- arrive, dan TIDAK di-unfreeze lagi di sini (sama kayak
-- driveStraightToWrapAssist) -- mobil dibiarin Anchored
-- sampai Step 7 ronde berikutnya.
--==========================================================

local function wrapDriveTimedTo(
    lineStart,
    lineEnd,
    desiredSeconds,
    arriveDistance
)

    desiredSeconds =
        desiredSeconds or 55

    arriveDistance =
        arriveDistance or 15


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    local car =
        vehicles
        and
        vehicles:FindFirstChild(
            player.Name .. "sCar"
        )

    if not car then
        return false
    end


    local character, hrp =
        getCharacter()


    local fullLine =
        lineEnd - lineStart

    local totalDistance =
        fullLine.Magnitude

    local lineDir =
        fullLine.Unit


    --==================================================
    -- SPEED = JARAK / WAKTU -- jaraknya dikurangin
    -- arriveDistance dulu, soalnya desiredSeconds itu
    -- ngukur waktu SAMPAI MASUK RADIUS ARRIVE, bukan
    -- sampai persis di titik tengah ATM (yang emang ga
    -- akan pernah kesentuh beneran karena loop-nya
    -- berhenti duluan begitu masuk radius itu).
    --==================================================

    local travelDistance =
        math.max(
            totalDistance - arriveDistance,
            1
        )

    local speed =
        travelDistance / desiredSeconds


    for _, part in ipairs(
        car:GetDescendants()
    ) do

        if part:IsA("BasePart") then

            part.Anchored = false

        end

    end


    performDriveMaintenance()


    VirtualInputManager:SendKeyEvent(
        true,
        Enum.KeyCode.W,
        false,
        game
    )


    local lastMaintenanceCheck =
        tick()

    local MAINTENANCE_INTERVAL = 2

    local lastStep =
        tick()

    local tripStart =
        tick()

    local reached = false


    --==================================================
    -- currentPos -- POSISI YANG KITA LACAK SENDIRI, BUKAN
    -- DIBACA BALIK DARI car:GetPivot() TIAP FRAME.
    --
    -- Mobil ga di-anchor (biar roda tetap keliatan muter),
    -- W juga ketahan terus -- itu artinya motor wheel
    -- A-Chassis-nya BENERAN narik mobil maju lewat fisik
    -- asli DI ATAS override PivotTo kita, di sela-sela dua
    -- frame (selama task.wait()). Kalau posisi "carPos" buat
    -- ngitung langkah berikutnya dibaca ULANG dari
    -- car:GetPivot() tiap frame, gerakan fisik ASLI itu ikut
    -- KETAMBAHIN ke atas increment wrap kita sendiri --
    -- DOUBLE-COUNT jarak, mobil jalan ~2x lebih kenceng dari
    -- speed yang diminta, makanya target 55 detik jadi ~27
    -- detik doang. Fix-nya: currentPos MURNI kita naikin
    -- sendiri sebesar moveDistance tiap frame, ga pernah
    -- dibaca ulang dari posisi fisik aktual mobil -- PivotTo
    -- tetap dipaksa ke currentPos ini tiap frame juga
    -- (nimpa/nge-cancel drift fisik dari W yang ketahan),
    -- jadi actual & tracked position selalu sinkron persis.
    --==================================================

    local currentPos =
        lineStart


    while
        autoRunning
    do

        if not ScreenGui.Parent then
            break
        end


        if
            tick() - lastMaintenanceCheck >
            MAINTENANCE_INTERVAL
        then

            lastMaintenanceCheck =
                tick()

            performDriveMaintenance()

        end


        local now =
            tick()

        local dt =
            now - lastStep

        lastStep = now


        local elapsed =
            now - tripStart

        if TimerLabel then

            TimerLabel.Text =
                "Waktu tempuh: " ..
                string.format(
                    "%.1f",
                    elapsed
                ) ..
                " s / target " ..
                string.format(
                    "%.0f",
                    desiredSeconds
                ) ..
                " s"

        end


        --==================================================
        -- OFFSET PLAYER DIAMBIL DARI CFRAME AKTUAL MOBIL
        -- SEKARANG (buat jaga posisi duduk relatif) -- ini
        -- BEDA dari currentPos yang jadi basis PERHITUNGAN
        -- LANGKAH -- lihat komentar currentPos di atas buat
        -- alasannya.
        --==================================================

        local carCFrame =
            car:GetPivot()


        local toEnd =
            lineEnd - currentPos

        local flatToEnd =
            Vector3.new(
                toEnd.X,
                0,
                toEnd.Z
            )

        local distanceToEnd =
            flatToEnd.Magnitude


        if distanceToEnd <= arriveDistance then

            --==================================================
            -- BERHENTI DI TEMPAT -- GA PERNAH DI-ANCHOR SAMA
            -- SEKALI (percobaan sebelumnya, "wrap ke atas ->
            -- lepas -> jatuhin", GAGAL -- begitu di-unanchor
            -- mobil malah TERUS MAJU lagi karena wheel motor-nya
            -- masih "inget" input W yang barusan dilepas, dan
            -- teleport paksa hrp.CFrame pas mobil masih
            -- Anchored bikin player keloncat pas fisiknya aktif
            -- lagi -- konflik sama seat weld beneran).
            --
            -- Fix yang lebih simpel & aman: mobil emang UDAH
            -- unanchored dari awal fungsi ini (lihat unanchor
            -- paksa di awal wrapDriveTimedTo) -- ga perlu
            -- di-anchor SAMA SEKALI buat berhenti. Cukup:
            -- 1. Lepas W.
            -- 2. Snap posisi akhir pas ke currentPos (biar
            --    presisi, ga nanggung di tengah gerakan).
            -- 3. Nol-in AssemblyLinearVelocity/AngularVelocity
            --    SEKALI -- karena velocity part selama ini
            --    DIPAKSA tiap frame (bukan hasil akselerasi
            --    fisik beneran), nol-in itu langsung bikin
            --    mobil diem total, ga ada residu momentum buat
            --    di-"decel"-in.
            -- 4. engageHandbrake() sebagai rem beneran (bukan
            --    Anchored) -- jaring pengaman ekstra biar ga
            --    kegeser meski udah 0 velocity.
            --
            -- Fisik mobil TETAP 100% normal/live dari awal
            -- sampai akhir -- ga ada Anchored yang perlu
            -- dibongkar lagi nanti, jadi koper di Step 10
            -- ke-detect normal kayak biasa.
            --==================================================

            VirtualInputManager:SendKeyEvent(
                false,
                Enum.KeyCode.W,
                false,
                game
            )


            local finalCFrame =
                CFrame.new(
                    currentPos,
                    currentPos + lineDir
                )

            local finalOffset =
                carCFrame:ToObjectSpace(
                    hrp.CFrame
                )

            car:PivotTo(
                finalCFrame
            )

            hrp.CFrame =
                finalCFrame * finalOffset


            for _, part in ipairs(
                car:GetDescendants()
            ) do

                if part:IsA("BasePart") then

                    part.AssemblyLinearVelocity =
                        Vector3.new(0, 0, 0)

                    part.AssemblyAngularVelocity =
                        Vector3.new(0, 0, 0)

                end

            end


            engageHandbrake()


            reached = true

            break

        end


        local offset =
            carCFrame:ToObjectSpace(
                hrp.CFrame
            )


        local moveDistance =
            math.min(
                speed * dt,
                distanceToEnd
            )


        currentPos =
            currentPos +
            lineDir * moveDistance

        local newCFrame =
            CFrame.new(
                currentPos,
                currentPos + lineDir
            )


        car:PivotTo(
            newCFrame
        )

        hrp.CFrame =
            newCFrame * offset


        local travelVelocity =
            lineDir * speed

        for _, part in ipairs(
            car:GetDescendants()
        ) do

            if part:IsA("BasePart") then

                part.AssemblyLinearVelocity =
                    travelVelocity

                part.AssemblyAngularVelocity =
                    Vector3.new(0, 0, 0)

            end

        end


        Status.Text =
            "Status: [7] Ditarik (timed, target " ..
            string.format(
                "%.0f",
                desiredSeconds
            ) ..
            "s)... jarak " ..
            string.format(
                "%.0f",
                distanceToEnd
            ) ..
            " studs"


        task.wait()

    end


    VirtualInputManager:SendKeyEvent(
        false,
        Enum.KeyCode.W,
        false,
        game
    )


    if TimerLabel then

        TimerLabel.Text =
            "Waktu tempuh TERAKHIR: " ..
            string.format(
                "%.1f",
                tick() - tripStart
            ) ..
            " s (target " ..
            string.format(
                "%.0f",
                desiredSeconds
            ) ..
            " s)"

    end


    return reached

end


--==========================================================
-- SAFE FIND CHILD
--==========================================================

local function waitForChildSafe(
    parent,
    name,
    timeout
)

    if not parent then
        return nil
    end


    local object =
        parent:FindFirstChild(
            name
        )


    if object then
        return object
    end


    local start =
        tick()


    while
        tick() - start < timeout
    do

        object =
            parent:FindFirstChild(
                name
            )


        if object then
            return object
        end


        task.wait(0.25)

    end


    return nil

end


--==========================================================
-- GET BCA
--==========================================================

local function getBCA()

    return waitForChildSafe(
        workspace,
        "MY_BCA_COLLAB",
        10
    )

end


--==========================================================
-- FIND PROMPT
--==========================================================

local function findPrompt(
    object
)

    if not object then
        return nil
    end


    return object:FindFirstChildWhichIsA(
        "ProximityPrompt",
        true
    )

end


--==========================================================
-- INTERACT
--==========================================================

local function interactObject(
    object
)

    local prompt =
        findPrompt(object)


    if not prompt then
        return false
    end


    fireproximityprompt(
        prompt
    )


    return true

end


--==========================================================
-- TOUCH ONCE
--==========================================================

local function touchOnce()

    local camera =
        workspace.CurrentCamera


    if not camera then
        return false
    end


    local viewport =
        camera.ViewportSize


    local x =
        viewport.X * 0.5


    local y =
        viewport.Y * 0.885


    VirtualInputManager:SendTouchEvent(
        0,
        Enum.UserInputState.Begin.Value,
        x,
        y
    )


    task.wait(0.1)


    VirtualInputManager:SendTouchEvent(
        0,
        Enum.UserInputState.End.Value,
        x,
        y
    )


    return true

end


--==========================================================
-- NPC DIALOG REMOTE
--==========================================================

local function getNpcDialogRemote()

    local network =
        ReplicatedStorage:FindFirstChild(
            "NetworkContainer"
        )


    if not network then
        return nil
    end


    local remoteEvents =
        network:FindFirstChild(
            "RemoteEvents"
        )


    if not remoteEvents then
        return nil
    end


    return remoteEvents:FindFirstChild(
        "NpcDialog"
    )

end


--==========================================================
-- BANK COURIER REMOTE
--==========================================================

local function getBankCourierRemote()

    local network =
        ReplicatedStorage:FindFirstChild(
            "NetworkContainer"
        )


    if not network then
        return nil
    end


    local remoteEvents =
        network:FindFirstChild(
            "RemoteEvents"
        )


    if not remoteEvents then
        return nil
    end


    return remoteEvents:FindFirstChild(
        "BankCourier"
    )

end


--==========================================================
-- CHECK VISIBLE GUI
--==========================================================

local function isActuallyVisible(
    guiObject
)

    if not guiObject.Visible then
        return false
    end


    local parent =
        guiObject.Parent


    while parent do

        if parent:IsA("GuiObject") then

            if not parent.Visible then
                return false
            end

        elseif parent:IsA("ScreenGui") then

            if not parent.Enabled then
                return false
            end

        end


        parent =
            parent.Parent

    end


    return true

end


--==========================================================
-- NpcDialog "Finish" DETECTOR (dipasang sekali saja)
--==========================================================

local npcDialog =
    getNpcDialogRemote()


if not getgenv().BCA_FinishDetectorInstalled then

    getgenv().BCA_FinishDetected = false

    if hookmetamethod then

        local oldNamecall

        oldNamecall =
            hookmetamethod(
                game,
                "__namecall",
                newcclosure(
                    function(
                        self,
                        ...
                    )

                        local method =
                            getnamecallmethod()


                        if
                            method == "FireServer"
                            and
                            npcDialog
                            and
                            self == npcDialog
                        then

                            local args = {
                                ...
                            }


                            if args[1] == "Finish" then

                                getgenv().BCA_FinishDetected =
                                    true

                            end

                        end


                        return oldNamecall(
                            self,
                            ...
                        )

                    end
                )
            )

        getgenv().BCA_OldNamecall =
            oldNamecall

        getgenv().BCA_FinishDetectorInstalled =
            true

    end

end


--==========================================================
-- TITIK PARKIR AMAN PER ATM (dipakai STEP 7)
--==========================================================

local atmSafeStops = {

    ATM1 =
        Vector3.new(
            6341.933594,
            21.815159,
            -7192.667969
        ),

    ATM2 =
        Vector3.new(
            2192.826416,
            28.073338,
            -4578.866699
        ),

    ATM3 =
        Vector3.new(
            821.880737,
            22.158598,
            -3792.762939
        ),

    ATM4 =
        Vector3.new(
            -1906.614624,
            23.770407,
            1171.328979
        ),

    ATM5 =
        Vector3.new(
            -4492.986816,
            25.727510,
            4352.214844
        ),

    ATM6 =
        Vector3.new(
            -4513.129883,
            22.768154,
            9698.768555
        ),

    ATM7 =
        Vector3.new(
            -441.681641,
            22.164188,
            8774.429688
        ),

    ATM8 =
        Vector3.new(
            -223.714020,
            22.950201,
            10710.350586
        ),

    ATM9 =
        Vector3.new(
            1542.021240,
            51.159866,
            865.166138
        ),

    ATM10 =
        Vector3.new(
            2047.485352,
            21.713932,
            -3513.444336
        ),

}


--==========================================================
-- INSTANCE -> CFRAME (dipakai STEP 9-12)
--==========================================================

local function atmGetInstanceCFrame(
    inst
)

    if not inst then
        return nil
    end

    if inst:IsA(
        "BasePart"
    ) then

        return inst.CFrame

    elseif inst:IsA(
        "Model"
    ) then

        return inst:GetPivot()

    elseif inst:IsA(
        "Attachment"
    ) then

        return CFrame.new(
            inst.WorldPosition
        )

    end

    return nil

end


local function atmTeleportPlayerTo(
    inst,
    zOffset
)

    local cframe =
        atmGetInstanceCFrame(
            inst
        )

    if not cframe then
        return false
    end

    local _, hrp =
        getCharacter()

    hrp.CFrame =
        cframe *
        CFrame.new(
            0,
            0,
            zOffset
        )

    return true

end


local atmCarName =
    player.Name .. "sCar"


local atmClosestATM = nil


--==========================================================
-- hasEnteredFloor -- dipakai sama Step 7 buat tau apa mobil
-- UDAH ada di atas lantai kotak (dari pengantaran koper
-- sebelumnya) atau BELUM (baru aja spawn, masih di ketinggian
-- CarSpawnerArea asli, di BAWAH lantai kotak yang udah
-- dinaikin FLOOR_Y_OFFSET stud). false = Step 7 masih perlu
-- teleportToStraightRoad ke floorEntryPoint dulu buat "naik"
-- ke lantai. true = mobil UDAH di lantai (nyangkut di ATM
-- sebelumnya), jadi Step 7 lanjut LANGSUNG dari posisi mobil
-- SEKARANG (deket ATM sebelumnya) ke ATM tujuan berikutnya --
-- ga usah balik ke spawner dulu tiap kali.
--==========================================================

local hasEnteredFloor = false


local function atmGetBagasiPoint()

    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    if not vehicles then
        return nil
    end

    local car =
        vehicles:FindFirstChild(
            atmCarName
        )

    if not car then
        return nil
    end

    return car:FindFirstChild(
        "BagasiPoint"
    )

end


local function atmGetDestinationCFrame()

    local route =
        workspace:FindFirstChild(
            "BankCourierRoute"
        )

    if not route then
        return nil
    end

    local destination =
        route:FindFirstChild(
            "To"
        )

    if not destination then
        return nil
    end

    return destination.CFrame

end


local function atmFindClosestATM(
    destinationPosition
)

    local bca =
        workspace:FindFirstChild(
            "MY_BCA_COLLAB"
        )

    if not bca then
        return nil
    end

    local job =
        bca:FindFirstChild(
            "Job"
        )

    if not job then
        return nil
    end

    local bankCourier =
        job:FindFirstChild(
            "BankCourier"
        )

    if not bankCourier then
        return nil
    end

    local atms =
        bankCourier:FindFirstChild(
            "ATMs"
        )

    if not atms then
        return nil
    end


    local closestATM = nil

    local closestDistance =
        math.huge


    for i = 1, 10 do

        local atm =
            atms:FindFirstChild(
                "ATM" ..
                tostring(i)
            )

        if atm then

            local atmCFrame =
                atmGetInstanceCFrame(
                    atm
                )

            if atmCFrame then

                local distance =
                    (
                        atmCFrame.Position
                        -
                        destinationPosition
                    ).Magnitude

                if distance <
                    closestDistance
                then

                    closestDistance =
                        distance

                    closestATM =
                        atm

                end

            end

        end

    end


    return closestATM

end


local function atmGetStatusLabel()

    local pg =
        player:WaitForChild(
            "PlayerGui"
        )

    local jobGui =
        waitForChildSafe(
            pg,
            "Job",
            10
        )

    if not jobGui then
        return nil
    end

    local bankCourierGui =
        waitForChildSafe(
            jobGui,
            "BankCourier",
            10
        )

    if not bankCourierGui then
        return nil
    end

    local statusGui =
        waitForChildSafe(
            bankCourierGui,
            "Status",
            10
        )

    if not statusGui then
        return nil
    end

    return waitForChildSafe(
        statusGui,
        "Atm",
        10
    )

end


local function atmGetProgress()

    local label =
        atmGetStatusLabel()

    if not label then
        return nil, nil, nil
    end

    local text =
        tostring(
            label.Text
        )

    local current, total =
        text:match(
            "ATM terisi:%s*(%d+)%s*/%s*(%d+)"
        )

    if not current
        or
        not total
    then
        return nil, nil, text
    end

    return
        tonumber(current),
        tonumber(total),
        text

end


local function atmGetBankCourierGui()

    local pg =
        player:WaitForChild(
            "PlayerGui"
        )

    local jobGui =
        waitForChildSafe(
            pg,
            "Job",
            10
        )

    if not jobGui then
        return nil
    end

    return waitForChildSafe(
        jobGui,
        "BankCourier",
        10
    )

end


--==========================================================
-- MINIGAME "GREAT GAP" (dipakai STEP 12)
--==========================================================

local function atmNormalizeAngle(
    angle
)

    angle =
        angle % 360

    if angle < 0 then
        angle = angle + 360
    end

    return angle

end


local function atmAngleDifference(
    a,
    b
)

    local diff =
        math.abs(
            atmNormalizeAngle(a) -
            atmNormalizeAngle(b)
        )

    return math.min(
        diff,
        360 - diff
    )

end


local function atmCircularMidpoint(
    a,
    b
)

    a =
        math.rad(
            atmNormalizeAngle(a)
        )

    b =
        math.rad(
            atmNormalizeAngle(b)
        )

    local x =
        math.cos(a) +
        math.cos(b)

    local y =
        math.sin(a) +
        math.sin(b)

    if
        math.abs(x) < 0.000001
        and
        math.abs(y) < 0.000001
    then

        return atmNormalizeAngle(
            math.deg(a)
        )

    end

    return atmNormalizeAngle(
        math.deg(
            math.atan2(
                y,
                x
            )
        )
    )

end


local function atmRunGreatGapMinigame(
    beforeCurrent,
    bankCourierRemote
)

    Status.Text =
        "Status: Menunggu minigame ATM..."


    local bankCourierGui =
        atmGetBankCourierGui()

    if not bankCourierGui then

        Status.Text =
            "Status: BankCourier GUI tidak ditemukan!"

        return false

    end


    local skill =
        waitForChildSafe(
            bankCourierGui,
            "Skill",
            10
        )

    if not skill then

        Status.Text =
            "Status: Skill GUI tidak ditemukan!"

        return false

    end


    local count =
        waitForChildSafe(
            skill,
            "Count",
            5
        )

    local needleArm =
        waitForChildSafe(
            skill,
            "NeedleArm",
            5
        )

    if not needleArm then

        Status.Text =
            "Status: NeedleArm tidak ditemukan!"

        return false

    end

    local tip =
        waitForChildSafe(
            needleArm,
            "Tip",
            5
        )

    if not tip then

        Status.Text =
            "Status: Tip tidak ditemukan!"

        return false

    end

    local greatArc =
        waitForChildSafe(
            skill,
            "GreatArc",
            5
        )

    if not greatArc then

        Status.Text =
            "Status: GreatArc tidak ditemukan!"

        return false

    end

    local leftHalf =
        waitForChildSafe(
            greatArc,
            "LeftHalf",
            5
        )

    local rightHalf =
        waitForChildSafe(
            greatArc,
            "RightHalf",
            5
        )

    if not leftHalf
        or
        not rightHalf
    then

        Status.Text =
            "Status: GreatArc Half tidak ditemukan!"

        return false

    end


    local TARGET_TOLERANCE = 5

    local wasInsideTarget = false


    local minigameStart =
        tick()


    while
        autoRunning
        and
        tick() - minigameStart < 30
    do

        if not ScreenGui.Parent then
            return false
        end


        --======================================================
        -- CEK COUNTER ATM DULU
        --======================================================

        local nowCurrent,
            nowTotal =
            atmGetProgress()

        if
            nowCurrent
            and
            nowTotal
            and
            nowCurrent > beforeCurrent
        then

            Status.Text =
                "Status: ATM " ..
                tostring(nowCurrent) ..
                "/" ..
                tostring(nowTotal) ..
                " berhasil!"

            return true

        end


        --======================================================
        -- TANDA MINIGAME AKTIF: Skill.Visible
        --======================================================

        if not skill.Visible then

            wasInsideTarget = false

            Status.Text =
                "Status: Menunggu minigame muncul..."

            task.wait(0.01)

        elseif
            count
            and
            count.Visible
        then

            wasInsideTarget = false

            Status.Text =
                "Status: Countdown minigame..."

            task.wait(0.03)

        else

            local tipRotation =
                atmNormalizeAngle(
                    tip.AbsoluteRotation
                )

            local leftRotation =
                atmNormalizeAngle(
                    leftHalf.AbsoluteRotation
                )

            local rightRotation =
                atmNormalizeAngle(
                    rightHalf.AbsoluteRotation
                )

            local targetCenter =
                atmCircularMidpoint(
                    leftRotation,
                    rightRotation
                )

            local targetDifference =
                atmAngleDifference(
                    tipRotation,
                    targetCenter
                )

            local inTarget =
                targetDifference <=
                TARGET_TOLERANCE


            if inTarget then

                if not wasInsideTarget then

                    wasInsideTarget = true


                    Status.Text =
                        "Status: Target terkunci, tunggu..."


                    task.wait(0.01)


                    if
                        not autoRunning
                        or
                        not ScreenGui.Parent
                    then

                        return false

                    end


                    bankCourierRemote:FireServer(
                        "SkillPress",
                        tip.AbsoluteRotation
                    )

                    Status.Text =
                        "Status: SkillPress terkirim!"

                end

            else

                Status.Text =
                    "Status: Minigame ATM " ..
                    string.format(
                        "%.1f",
                        targetDifference
                    ) ..
                    "°"

                wasInsideTarget = false

            end


            task.wait()

        end

    end


    return false

end


--==========================================================
-- WAIT SAMPAI TOGGLE AUTO NYALA LAGI
--==========================================================

local function waitForAutoOn()

    while not autoRunning do

        if not ScreenGui.Parent then
            return false
        end

        task.wait(0.2)

    end


    return ScreenGui.Parent ~= nil

end


--==========================================================
-- CEK APAKAH DIALOG NPC SEDANG TERBUKA
--
-- Dipakai sebagai verifikasi tambahan di setiap obrolan
-- NPC (Step 2 & Step 3): kalau belum pernah Visible berarti
-- dialog belum mulai, kalau Visible berarti lagi ngobrol,
-- dan begitu Visible balik jadi false (setelah sempat
-- Visible) berarti obrolan itu benar-benar sudah selesai.
--==========================================================

local function isNpcDialogVisible()

    local pg =
        player:FindFirstChild(
            "PlayerGui"
        )

    if not pg then
        return false
    end


    local npcDialogGui =
        pg:FindFirstChild(
            "NpcDialog"
        )

    if not npcDialogGui then
        return false
    end


    local textShadow =
        npcDialogGui:FindFirstChild(
            "TextShadow",
            true
        )

    if not textShadow then
        return false
    end


    if textShadow:IsA(
        "GuiObject"
    ) then

        return textShadow.Visible

    end


    return false

end


--==========================================================
-- STEP 1
-- TELEPORT KE NPC
--==========================================================

local startPosition =
    Vector3.new(
        1805.003,
        24.283,
        -4632.021
    )


local function runStep1()

    local character, hrp =
        getCharacter()


    Status.Text =
        "Status: [1] Melayang..."


    local wasAnchored =
        hrp.Anchored


    hrp.Anchored = true


    hrp.CFrame =
        CFrame.new(
            startPosition +
            Vector3.new(
                0,
                50,
                0
            )
        )


    task.wait(2)


    Status.Text =
        "Status: [1] Teleport ke lokasi BCA..."


    hrp.CFrame =
        CFrame.new(
            startPosition
        )


    task.wait(0.3)


    hrp.Anchored =
        wasAnchored


    Status.Text =
        "Status: [1] Sampai di lokasi NPC"


    return true

end


--==========================================================
-- STEP 2
-- INTERAKSI + TOUCH SAMPAI GAME MENGIRIM "Finish"
--==========================================================

--==========================================================
-- SATU RONDE NGOBROL SAMA NPC_START_JOB
--
-- Cari NPC -> interaksi -> touch sampai game
-- kirim "Finish". Dipanggil 2x di runStep2()
-- karena ternyata NPC-nya butuh diajak ngobrol
-- 2 ronde sebelum lanjut ke Car Spawner.
--==========================================================

local function npcDialogRound(
    roundLabel
)

    getgenv().BCA_FinishDetected =
        false


    Status.Text =
        "Status: [2] Mencari NPC (" ..
        roundLabel ..
        ")..."


    local bca =
        getBCA()

    if not bca then

        Status.Text =
            "Status: [2] BCA belum siap!"

        return false

    end


    local npc =
        waitForChildSafe(
            bca,
            "NPC_START_JOB",
            10
        )

    if not npc then

        Status.Text =
            "Status: [2] NPC_START_JOB tidak ditemukan!"

        return false

    end


    Status.Text =
        "Status: [2] Interaksi NPC (" ..
        roundLabel ..
        ")..."


    local interacted =
        interactObject(
            npc
        )

    if not interacted then

        Status.Text =
            "Status: [2] Prompt NPC tidak ditemukan!"

        return false

    end


    Status.Text =
        "Status: [2] Menunggu dialog (" ..
        roundLabel ..
        ")..."


    task.wait(1)


    --==================================================
    -- DOUBLE VERIFICATION (sama seperti Car Spawner)
    --
    -- hasBeenVisible = false -> dialog belum pernah
    -- terbuka (belum mulai). Begitu isNpcDialogVisible()
    -- kepantau true, artinya lagi ngobrol. Baru dianggap
    -- benar2 SELESAI kalau sudah pernah Visible lalu
    -- balik jadi not Visible lagi (bukan cuma Finish
    -- yang kedeteksi duluan sebelum dialog sempat kebuka).
    --==================================================

    local hasBeenVisible = false

    local clickCount = 0

    local maxClicks = 100


    while
        autoRunning
        and
        clickCount < maxClicks
    do

        if not ScreenGui.Parent then
            return false
        end


        local finishDetected =
            getgenv().BCA_FinishDetected

        local dialogVisible =
            isNpcDialogVisible()


        if dialogVisible then
            hasBeenVisible = true
        end


        if
            finishDetected
            and
            hasBeenVisible
            and
            not dialogVisible
        then

            Status.Text =
                "Status: [2] Dialog (" ..
                roundLabel ..
                ") selesai!"

            break

        end


        clickCount = clickCount + 1


        Status.Text =
            "Status: [2] Dialog (" ..
            roundLabel ..
            ") klik " ..
            tostring(clickCount)


        touchOnce()


        local waitStart =
            tick()


        while
            tick() - waitStart < 0.2
        do

            local currentFinish =
                getgenv().BCA_FinishDetected

            local currentVisible =
                isNpcDialogVisible()

            if currentVisible then
                hasBeenVisible = true
            end


            if
                currentFinish
                and
                hasBeenVisible
                and
                not currentVisible
            then

                break

            end


            task.wait(0.05)

        end

    end


    local finalFinish =
        getgenv().BCA_FinishDetected

    local finalVisible =
        isNpcDialogVisible()


    local success =
        finalFinish
        and
        hasBeenVisible
        and
        not finalVisible


    if success then

        Status.Text =
            "Status: [2] Dialog (" ..
            roundLabel ..
            ") benar-benar selesai!"

    elseif
        finalFinish
        and
        finalVisible
    then

        Status.Text =
            "Status: [2] Finish (" ..
            roundLabel ..
            ") ada, tapi dialog masih terbuka!"

    else

        Status.Text =
            "Status: [2] Finish (" ..
            roundLabel ..
            ") belum terdeteksi!"

    end


    return success

end


local function runStep2()

    --==================================================
    -- RONDE 1
    --==================================================

    if not npcDialogRound("1/2") then
        return false
    end


    task.wait(1)


    if not waitForAutoOn() then
        return false
    end


    --==================================================
    -- RONDE 2
    --
    -- NPC-nya ternyata butuh diajak ngobrol lagi
    -- setelah ronde pertama selesai, baru benar-benar
    -- siap lanjut ke Car Spawner.
    --==================================================

    if not npcDialogRound("2/2") then
        return false
    end


    return true

end


--==========================================================
-- STEP 3
-- CAR SPAWNER + DOUBLE VERIFICATION
--==========================================================

-- Titik berdiri CAR_SPAWNER_NPC (juga dipakai Step 4
-- buat teleport ke spawn vehicle -- posisinya emang
-- deket banget, jadi 1 titik yang sama dipakai bareng).
local carSpawnPosition =
    Vector3.new(
        1873.906,
        23.369,
        -4887.753
    )


local function runStep3()

    getgenv().BCA_FinishDetected =
        false


    Status.Text =
        "Status: [3] Mencari Car Spawner..."


    local bca =
        getBCA()

    if not bca then

        Status.Text =
            "Status: [3] BCA belum siap!"

        return false

    end


    local carSpawner =
        waitForChildSafe(
            bca,
            "CAR_SPAWNER_NPC",
            10
        )

    if not carSpawner then

        Status.Text =
            "Status: [3] CAR_SPAWNER_NPC tidak ditemukan!"

        return false

    end


    local character, hrp =
        getCharacter()


    Status.Text =
        "Status: [3] Teleport ke Car Spawner..."


    --==================================================
    -- LANGSUNG KE TITIK YANG UDAH DIKETAHUI, BUKAN
    -- NUNGGU "Head" NPC KETEMU
    --
    -- Nunggu Head si NPC (rig-nya) sempat bikin Step 3
    -- macet sampai 10 detik / gagal total kalau modelnya
    -- belum full selesai stream-in. Titik berdiri
    -- CAR_SPAWNER_NPC udah diketahui (carSpawnPosition),
    -- jadi langsung teleport ke situ aja -- ga perlu
    -- nunggu rig-nya sama sekali.
    --==================================================

    hrp.CFrame =
        CFrame.new(
            carSpawnPosition
        )


    task.wait(1)


    Status.Text =
        "Status: [3] Interaksi Car Spawner..."


    local interacted =
        interactObject(
            carSpawner
        )

    if not interacted then

        Status.Text =
            "Status: [3] Prompt Car Spawner tidak ditemukan!"

        return false

    end


    Status.Text =
        "Status: [3] Menunggu dialog..."


    task.wait(1)


    local clickCount = 0

    local maxClicks = 100


    while
        autoRunning
        and
        clickCount < maxClicks
    do

        if not ScreenGui.Parent then
            return false
        end


        local finishDetected =
            getgenv().BCA_FinishDetected

        local dialogVisible =
            isNpcDialogVisible()


        if
            finishDetected
            and
            not dialogVisible
        then

            Status.Text =
                "Status: [3] Car Spawner dialog selesai!"

            break

        end


        if finishDetected
            and
            dialogVisible
        then

            Status.Text =
                "Status: [3] Finish terdeteksi, dialog masih terbuka..."

        else

            Status.Text =
                "Status: [3] Dialog masih berjalan..."

        end


        clickCount = clickCount + 1


        touchOnce()


        local waitStart =
            tick()

        while
            tick() - waitStart < 0.2
        do

            local currentFinish =
                getgenv().BCA_FinishDetected

            local currentVisible =
                isNpcDialogVisible()

            if
                currentFinish
                and
                not currentVisible
            then

                break

            end

            task.wait(0.05)

        end

    end


    local finalFinish =
        getgenv().BCA_FinishDetected

    local finalDialogVisible =
        isNpcDialogVisible()


    if
        finalFinish
        and
        not finalDialogVisible
    then

        Status.Text =
            "Status: [3] Dialog benar-benar selesai!"

    elseif
        finalFinish
        and
        finalDialogVisible
    then

        Status.Text =
            "Status: [3] Finish ada, tapi dialog masih terbuka!"

    else

        Status.Text =
            "Status: [3] Finish belum terdeteksi!"

    end


    return
        finalFinish
        and
        not finalDialogVisible

end


--==========================================================
-- STEP 4
-- SPAWN VEHICLE
--==========================================================

local function runStep4()

    local character, hrp =
        getCharacter()


    Status.Text =
        "Status: [4] Menuju spawn vehicle..."


    hrp.CFrame =
        CFrame.new(
            carSpawnPosition
        )


    task.wait(1)


    local vehicles =
        waitForChildSafe(
            workspace,
            "Vehicles",
            10
        )

    if not vehicles then

        Status.Text =
            "Status: [4] Vehicles tidak ditemukan!"

        return false

    end


    local carName =
        player.Name .. "sCar"


    Status.Text =
        "Status: [4] Spawn " ..
        carName .. "..."


    local bankCourierRemote =
        getBankCourierRemote()

    if not bankCourierRemote then

        Status.Text =
            "Status: [4] BankCourier tidak ditemukan!"

        return false

    end


    bankCourierRemote:FireServer(
        "RespawnCar"
    )


    Status.Text =
        "Status: [4] Menunggu vehicle muncul..."


    local car = nil

    local startTime =
        tick()

    while
        tick() - startTime < 30
    do

        car =
            vehicles:FindFirstChild(
                carName
            )

        if car then
            break
        end

        task.wait(0.25)

    end


    if not car then

        Status.Text =
            "Status: [4] " ..
            carName ..
            " tidak muncul!"

        return false

    end


    Status.Text =
        "Status: [4] Vehicle berhasil spawn!"


    return true

end


--==========================================================
-- STEP 5
-- AUTO AMBIL + LOAD KOPER
--==========================================================

local function runStep5()

    local pg =
        player:WaitForChild(
            "PlayerGui"
        )

    local jobGui =
        waitForChildSafe(
            pg,
            "Job",
            10
        )

    if not jobGui then
        Status.Text =
            "Status: [5] Job GUI tidak ditemukan!"
        return false
    end


    local bankCourierGui =
        waitForChildSafe(
            jobGui,
            "BankCourier",
            10
        )

    if not bankCourierGui then
        Status.Text =
            "Status: [5] BankCourier tidak ditemukan!"
        return false
    end


    local statusGui =
        waitForChildSafe(
            bankCourierGui,
            "Status",
            10
        )

    if not statusGui then
        Status.Text =
            "Status: [5] Status tidak ditemukan!"
        return false
    end


    local koperStatus =
        waitForChildSafe(
            statusGui,
            "Koper",
            10
        )

    if not koperStatus then
        Status.Text =
            "Status: [5] Status.Koper tidak ditemukan!"
        return false
    end


    local function getKoperProgress()

        local text =
            tostring(
                koperStatus.Text
            )

        local current, total =
            text:match(
                "Koper di mobil:%s*(%d+)%s*/%s*(%d+)"
            )

        if not current
            or
            not total
        then
            return nil, nil, text
        end

        return
            tonumber(current),
            tonumber(total),
            text

    end


    local bca =
        getBCA()

    if not bca then
        Status.Text =
            "Status: [5] BCA belum siap!"
        return false
    end


    local job =
        waitForChildSafe(
            bca,
            "Job",
            10
        )

    if not job then
        Status.Text =
            "Status: [5] Job BCA tidak ditemukan!"
        return false
    end


    local bankCourierJob =
        waitForChildSafe(
            job,
            "BankCourier",
            10
        )

    if not bankCourierJob then
        Status.Text =
            "Status: [5] BankCourier Job tidak ditemukan!"
        return false
    end


    local koperSpawn =
        waitForChildSafe(
            bankCourierJob,
            "KoperSpawn",
            10
        )

    if not koperSpawn then
        Status.Text =
            "Status: [5] KoperSpawn tidak ditemukan!"
        return false
    end


    local koperPart =
        waitForChildSafe(
            koperSpawn,
            "Part",
            10
        )

    if not koperPart then
        Status.Text =
            "Status: [5] Part koper tidak ditemukan!"
        return false
    end


    local koperPrompt =
        koperPart:FindFirstChild(
            "Prompt"
        )

    if not koperPrompt then

        koperPrompt =
            koperPart:FindFirstChildWhichIsA(
                "ProximityPrompt",
                true
            )

    end

    if not koperPrompt then
        Status.Text =
            "Status: [5] Prompt koper tidak ditemukan!"
        return false
    end


    local bankCourierRemote =
        getBankCourierRemote()

    if not bankCourierRemote then
        Status.Text =
            "Status: [5] BankCourier Remote tidak ditemukan!"
        return false
    end


    local vehicles =
        waitForChildSafe(
            workspace,
            "Vehicles",
            10
        )

    if not vehicles then
        Status.Text =
            "Status: [5] Vehicles tidak ditemukan!"
        return false
    end


    local carName =
        player.Name .. "sCar"

    local car =
        vehicles:FindFirstChild(
            carName
        )

    if not car then
        Status.Text =
            "Status: [5] Vehicle belum spawn!"
        return false
    end


    local bagasiPoint = nil

    local bagasiStart =
        tick()

    while
        tick() - bagasiStart < 15
    do

        car =
            vehicles:FindFirstChild(
                carName
            )

        if car then

            bagasiPoint =
                car:FindFirstChild(
                    "BagasiPoint",
                    true
                )

        end

        if bagasiPoint then
            break
        end

        task.wait(0.25)

    end

    if not bagasiPoint then
        Status.Text =
            "Status: [5] BagasiPoint tidak ditemukan!"
        return false
    end


    --==================================================
    -- USED KOPER
    --
    -- Hanya supaya kita tidak memilih object
    -- yang sama berkali-kali dalam satu putaran.
    --==================================================

    local usedKopers = {}


    local function getAllKopers()

        local result = {}

        for _, obj in ipairs(
            koperSpawn:GetChildren()
        ) do

            if obj.Name:match(
                "^Koper%d+$"
            ) then

                table.insert(
                    result,
                    obj
                )

            end

        end


        table.sort(
            result,
            function(a, b)

                local aNumber =
                    tonumber(
                        a.Name:match(
                            "%d+"
                        )
                    )
                    or 0

                local bNumber =
                    tonumber(
                        b.Name:match(
                            "%d+"
                        )
                    )
                    or 0

                return aNumber < bNumber

            end
        )

        return result

    end


    local function isKoperAvailable(
        koper
    )

        if not koper then
            return false
        end

        if not koper.Parent then
            return false
        end


        local basePart

        if koper:IsA(
            "BasePart"
        ) then

            basePart = koper

        else

            basePart =
                koper:FindFirstChildWhichIsA(
                    "BasePart",
                    true
                )

        end

        if not basePart then
            return false
        end

        return true

    end


    local function findNextKoper()

        local kopers =
            getAllKopers()


        for _, koper in ipairs(
            kopers
        ) do

            if
                not usedKopers[koper]
                and
                isKoperAvailable(koper)
            then

                return koper

            end

        end


        --==============================================
        -- KALAU SEMUA OBJECT SUDAH DIGUNAKAN, RESET.
        -- Penting kalau game hanya punya Koper1-3
        -- tapi quest butuh 4 koper.
        --==============================================

        if #kopers > 0 then

            usedKopers = {}

            for _, koper in ipairs(
                kopers
            ) do

                if isKoperAvailable(
                    koper
                ) then

                    return koper

                end

            end

        end

        return nil

    end


    --==================================================
    -- KE TITIK "Part" YANG SUDAH DIKETAHUI, BUKAN KE
    -- INSTANCE Koper1/Koper2/dst.
    --
    -- koperPrompt yang beneran di-fire tiap putaran itu
    -- selalu prompt di koperPart ("Part") -- SATU titik
    -- tetap, bukan prompt masing-masing koper. Kalau
    -- player malah diteleport ke CFrame instance Koper
    -- (posisinya bisa ga presisi/beda dari koperPart),
    -- server bisa nolak fireproximityprompt karena
    -- player dianggap ga cukup deket ke prompt yang
    -- sebenarnya -> macet nunggu minigame yang ga pernah
    -- muncul. Titik koperPart ini udah pasti benar,
    -- ga perlu bedain per-instance koper lagi.
    --==================================================

    local function teleportToKoper(
        koper
    )

        local _, root =
            getCharacter()

        root.CFrame =
            koperPart.CFrame *
            CFrame.new(
                0,
                0,
                -3
            )

        return true

    end


    local function teleportToBagasi()

        local _, root =
            getCharacter()

        if bagasiPoint:IsA(
            "BasePart"
        ) then

            root.CFrame =
                bagasiPoint.CFrame *
                CFrame.new(
                    0,
                    0,
                    -2
                )

        elseif bagasiPoint:IsA(
            "Model"
        ) then

            root.CFrame =
                bagasiPoint:GetPivot() *
                CFrame.new(
                    0,
                    0,
                    -2
                )

        elseif bagasiPoint:IsA(
            "Attachment"
        ) then

            root.CFrame =
                CFrame.new(
                    bagasiPoint.WorldPosition
                )

        end

        return true

    end


    local function getMinigame()

        local timing =
            bankCourierGui:FindFirstChild(
                "Timing"
            )

        if not timing then
            return nil
        end

        local track =
            timing:FindFirstChild(
                "Track"
            )

        local trunk =
            timing:FindFirstChild(
                "Trunk"
            )

        if not track
            or
            not trunk
        then
            return nil
        end

        local koper =
            track:FindFirstChild(
                "Koper"
            )

        local slot =
            trunk:FindFirstChild(
                "Slot"
            )

        if not koper
            or
            not slot
        then
            return nil
        end

        return
            timing,
            track,
            koper,
            trunk,
            slot

    end


    local function waitForMinigame()

        Status.Text =
            "Status: [5] Menunggu minigame..."

        local start =
            tick()

        while
            tick() - start < 10
        do

            local timing,
                track,
                koper,
                trunk,
                slot =
                getMinigame()

            if
                koper
                and
                slot
                and
                isActuallyVisible(koper)
                and
                isActuallyVisible(slot)
            then

                return
                    timing,
                    track,
                    koper,
                    trunk,
                    slot

            end

            task.wait(0.05)

        end

        return nil

    end


    local function loadOneKoper(
        beforeCurrent,
        total
    )

        Status.Text =
            "Status: [5] Menuju bagasi " ..
            tostring(
                beforeCurrent + 1
            ) ..
            "/" ..
            tostring(total)


        teleportToBagasi()


        task.wait(0.5)


        local muatPrompt =
            bagasiPoint:FindFirstChild(
                "MuatPrompt",
                true
            )

        if not muatPrompt
            or
            not muatPrompt:IsA(
                "ProximityPrompt"
            )
        then

            Status.Text =
                "Status: [5] MuatPrompt tidak ditemukan!"

            return false

        end


        Status.Text =
            "Status: [5] Minigame " ..
            tostring(
                beforeCurrent + 1
            ) ..
            "/" ..
            tostring(total)


        fireproximityprompt(
            muatPrompt
        )


        local timing,
            track,
            koper,
            trunk,
            slot =
            waitForMinigame()

        if not koper
            or
            not slot
        then

            Status.Text =
                "Status: [5] Minigame tidak muncul!"

            return false

        end


        --==================================================
        -- JEDA SEBENTAR SEBELUM MULAI SCAN POSISI
        --
        -- AbsolutePosition/AbsoluteSize koper & slot bisa
        -- masih basi (frame sebelum GUI-nya bener-bener
        -- ke-render/layout ulang) tepat di frame pertama
        -- minigame ini kelihatan. Kalau scanPosition() jalan
        -- terlalu cepat, kebetulan bisa kebaca "udah pas di
        -- slot" padahal belum, LoadPress ke-fire kepagian
        -- dan server nolak -> minigame keliatan sekilas terus
        -- langsung reset ("ke-skip"). Kasih jeda dikit dulu
        -- biar Roblox sempat layout ulang UI-nya bener.
        --==================================================

        task.wait(0.2)


        local locked = false

        local connection


        local function scanPosition()

            if locked then
                return true
            end

            if
                not koper.Parent
                or
                not slot.Parent
            then
                return false
            end


            local koperPosition =
                koper.Position

            local koperLeft =
                track.AbsolutePosition.X
                +
                (
                    koperPosition.X.Scale
                    *
                    track.AbsoluteSize.X
                )
                +
                koperPosition.X.Offset

            local koperCenter =
                koperLeft
                +
                (
                    koper.AbsoluteSize.X
                    /
                    2
                )


            local slotPosition =
                slot.Position

            local slotLeft =
                trunk.AbsolutePosition.X
                +
                (
                    slotPosition.X.Scale
                    *
                    trunk.AbsoluteSize.X
                )
                +
                slotPosition.X.Offset

            local slotRight =
                slotLeft
                +
                slot.AbsoluteSize.X


            if
                koperCenter >= slotLeft
                and
                koperCenter <= slotRight
            then

                locked = true

                Status.Text =
                    "Status: [5] Posisi pas → Load!"

                task.wait(0.05)

                bankCourierRemote:FireServer(
                    "LoadPress"
                )

                return true

            end

            return false

        end


        connection =
            koper:GetPropertyChangedSignal(
                "Position"
            ):Connect(
                function()

                    if
                        autoRunning
                        and
                        not locked
                    then

                        pcall(
                            scanPosition
                        )

                    end

                end
            )


        local scanStart =
            tick()

        while
            autoRunning
            and
            not locked
            and
            tick() - scanStart < 30
        do

            pcall(
                scanPosition
            )

            task.wait(0.01)

        end


        if connection then
            connection:Disconnect()
            connection = nil
        end


        if not locked then

            Status.Text =
                "Status: [5] Minigame gagal!"

            return false

        end


        Status.Text =
            "Status: [5] Menunggu koper tercatat..."


        local counterStart =
            tick()

        while
            autoRunning
            and
            tick() - counterStart < 10
        do

            local nowCurrent,
                nowTotal =
                getKoperProgress()

            if
                nowCurrent
                and
                nowTotal
                and
                nowCurrent > beforeCurrent
            then

                Status.Text =
                    "Status: [5] " ..
                    tostring(nowCurrent) ..
                    "/" ..
                    tostring(nowTotal) ..
                    " berhasil!"

                return true

            end

            task.wait(0.05)

        end


        Status.Text =
            "Status: [5] Counter koper tidak berubah!"

        return false

    end


    --==================================================
    -- MAIN LOOP
    --==================================================

    while autoRunning do

        local current,
            total =
            getKoperProgress()

        if not current
            or
            not total
        then

            Status.Text =
                "Status: [5] Tidak bisa membaca jumlah koper!"

            break

        end


        if current >= total then

            Status.Text =
                "Status: [5] SEMUA KOPER SELESAI! " ..
                tostring(current) ..
                "/" ..
                tostring(total)

            break

        end


        Status.Text =
            "Status: [5] Mencari koper berikutnya..."


        local koper =
            findNextKoper()

        if not koper then

            Status.Text =
                "Status: [5] Menunggu koper tersedia..."

            local waitStart =
                tick()

            while
                autoRunning
                and
                tick() - waitStart < 15
            do

                koper =
                    findNextKoper()

                if koper then
                    break
                end

                task.wait(0.25)

            end

        end

        if not koper then

            Status.Text =
                "Status: [5] Koper berikutnya tidak ditemukan!"

            break

        end


        usedKopers[koper] = true


        Status.Text =
            "Status: [5] Mengambil koper..."


        local teleported =
            teleportToKoper(
                koper
            )

        if not teleported then

            Status.Text =
                "Status: [5] Gagal teleport ke koper!"

            break

        end


        task.wait(0.8)


        fireproximityprompt(
            koperPrompt
        )


        task.wait(1)


        local loaded =
            loadOneKoper(
                current,
                total
            )

        if not loaded then

            Status.Text =
                "Status: [5] Gagal load koper!"

            break

        end


        task.wait(0.5)

    end


    local finalCurrent,
        finalTotal =
        getKoperProgress()


    if
        finalCurrent
        and
        finalTotal
    then

        if
            finalCurrent >= finalTotal
        then

            Status.Text =
                "Status: [5] SELESAI " ..
                tostring(finalCurrent) ..
                "/" ..
                tostring(finalTotal)

            return true

        else

            Status.Text =
                "Status: [5] Berhenti di " ..
                tostring(finalCurrent) ..
                "/" ..
                tostring(finalTotal)

            return false

        end

    end


    return false

end


--==========================================================
-- STEP 6
-- NAIK MOBIL
--==========================================================

local function runStep6()

    local function getCharacterLocal()

        return player.Character
            or player.CharacterAdded:Wait()

    end


    local function getRootLocal()

        local character =
            getCharacterLocal()

        return character:WaitForChild(
            "HumanoidRootPart"
        )

    end


    local function isInCar()

        local pg =
            player:WaitForChild(
                "PlayerGui"
            )

        local chassis =
            pg:FindFirstChild(
                "A-Chassis Interface"
            )

        return chassis ~= nil

    end


    if isInCar() then

        Status.Text =
            "Status: [6] Sudah di dalam mobil!"

        return true

    end


    Status.Text =
        "Status: [6] Mencari mobil..."


    local vehicles =
        workspace:FindFirstChild(
            "Vehicles"
        )

    if not vehicles then

        Status.Text =
            "Status: [6] Vehicles tidak ditemukan!"

        return false

    end


    local carName =
        player.Name .. "sCar"

    local car =
        vehicles:FindFirstChild(
            carName
        )

    if not car then

        Status.Text =
            "Status: [6] " ..
            carName ..
            " belum ditemukan!"

        return false

    end


    local body =
        car:FindFirstChild(
            "Body"
        )

    if not body then

        Status.Text =
            "Status: [6] Body mobil tidak ditemukan!"

        return false

    end


    local rm =
        body:FindFirstChild(
            "RM"
        )

    if not rm then

        Status.Text =
            "Status: [6] RM pintu driver tidak ditemukan!"

        return false

    end


    Status.Text =
        "Status: [6] Teleport ke pintu driver..."


    local root =
        getRootLocal()

    local rmCFrame = nil

    if rm:IsA(
        "BasePart"
    ) then

        rmCFrame =
            rm.CFrame

    elseif rm:IsA(
        "Model"
    ) then

        rmCFrame =
            rm:GetPivot()

    end

    if not rmCFrame then

        Status.Text =
            "Status: [6] CFrame RM tidak ditemukan!"

        return false

    end


    root.CFrame =
        rmCFrame *
        CFrame.new(
            0,
            0,
            -2
        )


    task.wait(0.5)


    Status.Text =
        "Status: [6] Mencari Drive Prompt..."


    local drivePrompt = nil


    for _, obj in ipairs(
        rm:GetDescendants()
    ) do

        if obj:IsA(
            "ProximityPrompt"
        ) then

            if
                obj.ActionText == "Drive"
                or
                obj.ObjectText == "Drive"
            then

                drivePrompt = obj
                break

            end

        end

    end


    if not drivePrompt then

        for _, obj in ipairs(
            rm:GetDescendants()
        ) do

            if obj:IsA(
                "ProximityPrompt"
            )
            and
            obj.Enabled
            then

                drivePrompt = obj
                break

            end

        end

    end


    if not drivePrompt then

        local rmPosition

        if rm:IsA(
            "BasePart"
        ) then

            rmPosition =
                rm.Position

        elseif rm:IsA(
            "Model"
        ) then

            rmPosition =
                rm:GetPivot().Position

        end


        if rmPosition then

            local closestDistance =
                10

            for _, obj in ipairs(
                workspace:GetDescendants()
            ) do

                if obj:IsA(
                    "ProximityPrompt"
                )
                and
                obj.Enabled
                then

                    local parent =
                        obj.Parent

                    if parent
                        and
                        parent:IsA(
                            "BasePart"
                        )
                    then

                        local distance =
                            (
                                parent.Position
                                -
                                rmPosition
                            ).Magnitude

                        if distance <
                            closestDistance
                        then

                            closestDistance =
                                distance

                            drivePrompt =
                                obj

                        end

                    end

                end

            end

        end

    end


    if not drivePrompt then

        Status.Text =
            "Status: [6] Drive Prompt tidak ditemukan!"

        return false

    end


    Status.Text =
        "Status: [6] Mencoba naik mobil..."


    for attempt = 1, 5 do

        if isInCar() then

            Status.Text =
                "Status: [6] Berhasil naik mobil!"

            return true

        end


        Status.Text =
            "Status: [6] Naik mobil " ..
            tostring(attempt) ..
            "/5..."


        root =
            getRootLocal()

        root.CFrame =
            rmCFrame *
            CFrame.new(
                0,
                0,
                -2
            )


        task.wait(0.25)


        if drivePrompt
            and
            drivePrompt.Parent
            and
            drivePrompt.Enabled
        then

            fireproximityprompt(
                drivePrompt
            )

        else

            for _, obj in ipairs(
                rm:GetDescendants()
            ) do

                if obj:IsA(
                    "ProximityPrompt"
                )
                and
                obj.Enabled
                then

                    drivePrompt = obj
                    break

                end

            end

            if drivePrompt then

                fireproximityprompt(
                    drivePrompt
                )

            end

        end


        local start =
            tick()

        while
            tick() - start < 2
        do

            if isInCar() then

                Status.Text =
                    "Status: [6] BERHASIL NAIK MOBIL!"

                return true

            end

            task.wait(0.1)

        end

    end


    if isInCar() then

        Status.Text =
            "Status: [6] BERHASIL NAIK MOBIL!"

        return true

    end


    Status.Text =
        "Status: [6] Gagal naik mobil!"

    return false

end


--==========================================================
-- STEP 7
-- ANTAR KE ATM
--==========================================================

local function runStep7()

    Status.Text =
        "Status: [7] Mencari tujuan ATM..."


    local route =
        workspace:FindFirstChild(
            "BankCourierRoute"
        )

    if not route then

        Status.Text =
            "Status: [7] BankCourierRoute tidak ditemukan!"

        return false

    end


    local destination =
        route:FindFirstChild(
            "To"
        )

    if not destination then

        Status.Text =
            "Status: [7] Route.To tidak ditemukan!"

        return false

    end


    local destinationCFrame =
        destination.CFrame

    local destinationPosition =
        destinationCFrame.Position


    Status.Text =
        "Status: [7] Tujuan terdeteksi..."


    local bca =
        workspace:FindFirstChild(
            "MY_BCA_COLLAB"
        )

    if not bca then

        Status.Text =
            "Status: [7] MY_BCA_COLLAB tidak ditemukan!"

        return false

    end


    local job =
        bca:FindFirstChild(
            "Job"
        )

    if not job then

        Status.Text =
            "Status: [7] Job tidak ditemukan!"

        return false

    end


    local bankCourier =
        job:FindFirstChild(
            "BankCourier"
        )

    if not bankCourier then

        Status.Text =
            "Status: [7] BankCourier tidak ditemukan!"

        return false

    end


    local atms =
        bankCourier:FindFirstChild(
            "ATMs"
        )

    if not atms then

        Status.Text =
            "Status: [7] ATMs tidak ditemukan!"

        return false

    end


    local closestATM = nil

    local closestDistance =
        math.huge


    for i = 1, 10 do

        local atm =
            atms:FindFirstChild(
                "ATM" ..
                tostring(i)
            )

        if atm then

            local atmCFrame = nil

            if atm:IsA(
                "BasePart"
            ) then

                atmCFrame =
                    atm.CFrame

            elseif atm:IsA(
                "Model"
            ) then

                atmCFrame =
                    atm:GetPivot()

            end

            if atmCFrame then

                local distance =
                    (
                        atmCFrame.Position
                        -
                        destinationPosition
                    ).Magnitude

                if distance <
                    closestDistance
                then

                    closestDistance =
                        distance

                    closestATM =
                        atm

                end

            end

        end

    end


    if not closestATM then

        Status.Text =
            "Status: [7] Tidak menemukan ATM!"

        return false

    end


    local atmCFrame = nil

    if closestATM:IsA(
        "BasePart"
    ) then

        atmCFrame =
            closestATM.CFrame

    elseif closestATM:IsA(
        "Model"
    ) then

        atmCFrame =
            closestATM:GetPivot()

    end

    if not atmCFrame then

        Status.Text =
            "Status: [7] CFrame ATM tidak ditemukan!"

        return false

    end


    Status.Text =
        "Status: [7] Tujuan = " ..
        closestATM.Name


    task.wait(0.5)


    --==================================================
    -- LANTAI KOTAK SEJAJAR TANAH (bukan hub-and-spoke,
    -- bukan garis dekoi 1D, dan BUKAN di langit -- sejajar
    -- persis sama CarSpawnerArea)
    --
    -- 1. Teleport INSTAN ke titik ENTRY (tepat di
    --    CarSpawnerArea, sejajar lantai) -- dari
    --    manapun mobil sekarang berada (ATM sebelumnya,
    --    car spawner, dst), jadi "balik ke spawner"
    --    kejadian otomatis tiap kali Step 7 ini jalan.
    -- 2. Nyetir BENERAN (driveStraightTo, pure-pursuit, W
    --    ditahan gaspol terus) LURUS dari titik entry ke
    --    titik SEJAJAR (X/Z sama) ATM TUJUAN SEBENARNYA --
    --    GA ADA LAGI fase wrap-drag (wrapDriveStraightTo)
    --    nyambung di belakangnya -- mobil ga perlu "ditarik"
    --    ke plafon/ketinggian ATM sama sekali, cukup nyetir
    --    fisik doang sampai deket, selama masih di dalam
    --    bounding box lantai, dijamin ga akan pernah
    --    jatuh/nyangkut, jarak yang ditempuh di sini yang
    --    dipakai game buat ngitung gaji.
    -- 3. Begitu udah sejajar, mobil BERHENTI DI SITU JUGA --
    --    GA ADA LAGI teleport naik/turun ke papan parkir
    --    terpisah (dulu wrapToLocationSoft ke atmSafeStops).
    --    Papan parkir (Parkir1..10) udah dihapus dari
    --    LANDMARKS -- ketinggiannya beda dari lantai bikin
    --    pinggirnya jadi tembok/curb yang bikin mobil nabrak
    --    & nyangkut. Ga masalah mobil parkir "di atas" atau
    --    "di bawah" ATM aslinya (beda ketinggian) -- toh
    --    Step 8-10 (keluar mobil, ke bagasi, ambil koper)
    --    kerja relatif ke MOBIL itu sendiri, bukan ke ATM.
    --    Baru Step 11 nanti yang TELEPORT PLAYER (bukan
    --    mobil) ke ATM aslinya buat minigame.
    --==================================================

    local floorEntryPoint =
        getgenv().MerdekaFloorEntryPoint

    local floorY =
        getgenv().MerdekaFloorY

    local floorTargetPoint =
        floorY
        and Vector3.new(
            atmCFrame.Position.X,
            floorY + 1,
            atmCFrame.Position.Z
        )

    if floorEntryPoint and floorTargetPoint then

        local ATM_FLOOR_ARRIVE_DISTANCE = 35

        --==============================================
        -- hasEnteredFloor == false -> ini pengantaran
        -- PERTAMA, mobil masih di ketinggian CarSpawnerArea
        -- asli (di BAWAH lantai kotak) -- teleport dulu ke
        -- floorEntryPoint kayak biasa buat "naik" ke lantai.
        --
        -- hasEnteredFloor == true -> mobil UDAH di atas
        -- lantai (nyangkut deket ATM sebelumnya) -- GA USAH
        -- balik teleport ke spawner lagi, lanjut LANGSUNG
        -- dari posisi mobil sekarang. Tapi geser 50 stud ke
        -- samping (tegak lurus arah ke ATM baru) dulu sebagai
        -- "safety maneuver" -- ATM sebelumnya punya jalan
        -- kecil yang menonjol dari lantai, geser dulu biar
        -- mobil ga langsung narik lurus nabrak pinggir
        -- tonjolan itu.
        --==============================================

        local driveLineStart = floorEntryPoint

        if not hasEnteredFloor then

            Status.Text =
                "Status: [7] Teleport ke lantai (hover -> turun pelan)..."

            teleportToStraightRoad(
                floorEntryPoint,
                floorTargetPoint
            )

            hasEnteredFloor = true

        else

            local vehicles =
                workspace:FindFirstChild("Vehicles")

            local car =
                vehicles
                and
                vehicles:FindFirstChild(
                    player.Name .. "sCar"
                )

            local currentCarPos =
                car
                and car:GetPivot().Position

            if currentCarPos then

                driveLineStart = currentCarPos

                local mainDir =
                    floorTargetPoint - currentCarPos

                if mainDir.Magnitude > 0.001 then

                    mainDir = mainDir.Unit

                    local rightDir =
                        Vector3.new(
                            mainDir.Z,
                            0,
                            -mainDir.X
                        )

                    local SLIDE_DISTANCE = 50
                    local SLIDE_DURATION = 1.5
                    local SLIDE_ARRIVE_DISTANCE = 3

                    local slidePoint =
                        currentCarPos
                        +
                        rightDir * SLIDE_DISTANCE

                    Status.Text =
                        "Status: [7] Geser 50 stud sebelum ke " ..
                        closestATM.Name .. "..."

                    wrapDriveTimedTo(
                        currentCarPos,
                        slidePoint,
                        SLIDE_DURATION,
                        SLIDE_ARRIVE_DISTANCE
                    )

                    driveLineStart = slidePoint

                end

            else

                -- Mobil ga ketemu (despawn dll) -- fallback
                -- ke cara lama, teleport balik ke spawner.

                Status.Text =
                    "Status: [7] Teleport ke lantai (hover -> turun pelan)..."

                teleportToStraightRoad(
                    floorEntryPoint,
                    floorTargetPoint
                )

                driveLineStart = floorEntryPoint

            end

        end


        --==============================================
        -- VERSI "WRAP TIMED" -- CFrame-drag MURNI (bukan
        -- fisik/gaspol lagi), tapi KECEPATANNYA DIHITUNG
        -- OTOMATIS dari wrapTravelTimeSeconds (target waktu
        -- tempuh, bisa diganti langsung dari GUI TextBox
        -- "Target waktu tempuh") supaya mobil SELALU nyampe
        -- ATM tujuan dalam kira-kira segitu detik, ATM
        -- manapun jaraknya (random) -- lihat wrapDriveTimedTo
        -- buat detail rumus speed = jarak/waktu-nya.
        --
        -- Begitu masuk radius arrive, wrapDriveTimedTo lepas W +
        -- nol-in velocity + engageHandbrake() -- mobil berhenti
        -- di tempat TANPA PERNAH DI-ANCHOR sama sekali (fisiknya
        -- 100% normal/live terus dari awal sampai akhir), jadi
        -- koper di Step 10 ke-detect normal kayak biasa.
        --==============================================

        Status.Text =
            "Status: [7] Ditarik (timed) ke " ..
            closestATM.Name .. "..."

        wrapDriveTimedTo(
            driveLineStart,
            floorTargetPoint,
            wrapTravelTimeSeconds,
            ATM_FLOOR_ARRIVE_DISTANCE
        )

    end


    --==================================================
    -- MOBIL BERHENTI DI SINI JUGA -- ga ada lagi teleport
    -- naik/turun ke papan parkir terpisah (dulu
    -- wrapToLocationSoft ke atmSafeStops). Begitu masuk
    -- radius arrive, wrapDriveTimedTo langsung freeze
    -- instan di tempat (ga di-unfreeze lagi di sini) --
    -- Step 8 (keluar mobil) lanjut dari posisi beku ini
    -- lewat task.wait(1) generik yang sama kayak semua
    -- transisi step lain di runFullCycle.
    --==================================================

    Status.Text =
        "Status: [7] Sampai di " ..
        closestATM.Name


    return true

end


--==========================================================
-- STEP 8
-- KELUAR MOBIL (JUMP)
--==========================================================

local function runStep8()

    local function isInCar()

        local pg =
            player:WaitForChild(
                "PlayerGui"
            )

        local chassis =
            pg:FindFirstChild(
                "A-Chassis Interface"
            )

        return chassis ~= nil

    end


    if not isInCar() then

        Status.Text =
            "Status: [8] Tidak sedang di dalam mobil!"

        return true

    end


    Status.Text =
        "Status: [8] Keluar mobil..."


    local character =
        player.Character
        or
        player.CharacterAdded:Wait()

    local humanoid =
        character:FindFirstChildOfClass(
            "Humanoid"
        )


    for attempt = 1, 10 do

        if not isInCar() then

            Status.Text =
                "Status: [8] Berhasil keluar mobil!"

            return true

        end


        if not humanoid then

            character =
                player.Character
                or
                player.CharacterAdded:Wait()

            humanoid =
                character:FindFirstChildOfClass(
                    "Humanoid"
                )

        end


        local seat =
            humanoid
            and
            humanoid.SeatPart


        if humanoid then

            humanoid.Jump = true
            humanoid.Sit = false

        end


        task.wait(0.3)


        if not isInCar() then

            Status.Text =
                "Status: [8] Berhasil keluar mobil!"

            return true

        end


        if seat
            and
            seat:IsA("VehicleSeat")
        then

            seat.Disabled = true

            task.wait(0.2)

            seat.Disabled = false

        end


        task.wait(0.3)

    end


    if isInCar() then

        Status.Text =
            "Status: [8] Gagal keluar mobil!"

        return false

    end


    Status.Text =
        "Status: [8] Berhasil keluar mobil!"

    return true

end


--==========================================================
-- STEP 9
-- KE BELAKANG MOBIL
--==========================================================

local function runStep9()

    Status.Text =
        "Status: [9] Mencari bagasi mobil..."


    local bagasiPoint =
        atmGetBagasiPoint()

    if not bagasiPoint then

        Status.Text =
            "Status: [9] BagasiPoint tidak ditemukan!"

        return false

    end


    atmTeleportPlayerTo(
        bagasiPoint,
        -2
    )


    Status.Text =
        "Status: [9] Sampai di belakang mobil!"


    return true

end


--==========================================================
-- STEP 10
-- AMBIL KOPER
--==========================================================

local function runStep10()

    local bagasiPoint =
        atmGetBagasiPoint()

    if not bagasiPoint then

        Status.Text =
            "Status: [10] BagasiPoint tidak ditemukan!"

        return false

    end


    local ambilPrompt =
        bagasiPoint:FindFirstChild(
            "AmbilPrompt"
        )

    if not ambilPrompt then

        Status.Text =
            "Status: [10] AmbilPrompt tidak ditemukan!"

        return false

    end


    --==================================================
    -- AmbilPrompt BERTIPE "HOLD"
    --==================================================

    Status.Text =
        "Status: [10] Mengambil koper (hold " ..
        string.format(
            "%.1f",
            ambilPrompt.HoldDuration
        ) ..
        "s)..."


    ambilPrompt:InputHoldBegin()


    task.wait(
        ambilPrompt.HoldDuration +
        0.3
    )


    ambilPrompt:InputHoldEnd()


    Status.Text =
        "Status: [10] Koper berhasil diambil!"


    return true

end


--==========================================================
-- STEP 11
-- TELEPORT KE ATM
--==========================================================

local function runStep11()

    Status.Text =
        "Status: [11] Mencari tujuan ATM..."


    local destinationCFrame =
        atmGetDestinationCFrame()

    if not destinationCFrame then

        Status.Text =
            "Status: [11] Route.To tidak ditemukan!"

        return false

    end


    local closestATM =
        atmFindClosestATM(
            destinationCFrame.Position
        )

    if not closestATM then

        Status.Text =
            "Status: [11] Tidak menemukan ATM!"

        return false

    end


    atmClosestATM = closestATM


    local atmScreen =
        closestATM:FindFirstChild(
            "Screen_ATM_01",
            true
        )

    if not atmScreen then

        Status.Text =
            "Status: [11] Screen_ATM_01 tidak ditemukan!"

        return false

    end


    Status.Text =
        "Status: [11] Menuju " ..
        closestATM.Name ..
        "..."


    atmTeleportPlayerTo(
        atmScreen,
        -2
    )


    Status.Text =
        "Status: [11] Sampai di " ..
        closestATM.Name


    return true

end


--==========================================================
-- STEP 12
-- BUKA ATM + KERJAKAN MINIGAME
--==========================================================

local function runStep12()

    if not atmClosestATM then

        Status.Text =
            "Status: [12] Belum ada ATM tujuan!"

        return false

    end


    local beforeCurrent =
        atmGetProgress()

    if not beforeCurrent then

        Status.Text =
            "Status: [12] Tidak bisa membaca progress ATM!"

        return false

    end


    local bankCourierRemote =
        getBankCourierRemote()

    if not bankCourierRemote then

        Status.Text =
            "Status: [12] BankCourier Remote tidak ditemukan!"

        return false

    end


    --==================================================
    -- BUKA ATM
    --
    -- Bukan ProximityPrompt, tapi FireServer
    -- langsung ke remote BankCourier dengan
    -- argumen "FillStart".
    --==================================================

    Status.Text =
        "Status: [12] Membuka " ..
        atmClosestATM.Name ..
        "..."


    bankCourierRemote:FireServer(
        "FillStart"
    )


    local success =
        atmRunGreatGapMinigame(
            beforeCurrent,
            bankCourierRemote
        )

    if success then

        Status.Text =
            "Status: [12] Minigame berhasil!"

    else

        Status.Text =
            "Status: [12] Minigame gagal / timeout!"

    end


    return success

end


--==========================================================
-- SATU SIKLUS PENUH
--
-- Step 1-5 sekali (ngobrol NPC, spawn mobil, load
-- semua koper ke bagasi). Lalu 6-12 diulang PER
-- KOPER (naik mobil, antar ke ATM tujuan koper itu,
-- keluar mobil, ambil koper dari bagasi, setor,
-- ulangi) sampai semua koper terkirim, baru balik
-- ke NPC awal.
--==========================================================

local function runFullCycle()

    if not runStep1() then return false end
    task.wait(0.5)
    if not waitForAutoOn() then return false end

    if not runStep2() then return false end
    task.wait(0.5)
    if not waitForAutoOn() then return false end

    if not runStep3() then return false end
    task.wait(0.5)
    if not waitForAutoOn() then return false end

    if not runStep4() then return false end
    task.wait(0.5)
    if not waitForAutoOn() then return false end

    if not runStep5() then return false end
    task.wait(0.5)
    if not waitForAutoOn() then return false end


    --==================================================
    -- LOOP DELIVER SAMPAI SEMUA KOPER SELESAI
    --
    -- Tiap koper bisa jadi tujuan ATM-nya beda tempat,
    -- jadi naik-antar-keluar mobil (6-7-8) diulang
    -- setiap putaran, bukan cuma sekali di awal.
    --==================================================

    while true do

        if not ScreenGui.Parent then
            return false
        end

        if not waitForAutoOn() then
            return false
        end


        local current,
            total =
            atmGetProgress()

        if not current
            or
            not total
        then

            Status.Text =
                "Status: Gagal baca progress ATM!"

            return false

        end


        if current >= total then

            Status.Text =
                "Status: SEMUA KOPER TERKIRIM (" ..
                tostring(current) ..
                "/" ..
                tostring(total) ..
                ")! Kembali ke NPC..."

            break

        end


        if not runStep6() then return false end
        task.wait(0.5)
        if not waitForAutoOn() then return false end

        if not runStep7() then return false end
        task.wait(0.5)
        if not waitForAutoOn() then return false end

        if not runStep8() then return false end
        task.wait(0.5)
        if not waitForAutoOn() then return false end

        if not runStep9() then return false end
        task.wait(0.5)
        if not waitForAutoOn() then return false end

        if not runStep10() then return false end
        task.wait(0.5)
        if not waitForAutoOn() then return false end

        if not runStep11() then return false end
        task.wait(0.5)
        if not waitForAutoOn() then return false end

        if not runStep12() then return false end
        task.wait(0.5)

    end


    return true

end


--==========================================================
-- DRAG GUI
--
-- GUI kecil ini ga punya Title bar terpisah lagi (dihapus
-- bareng GUI lama) -- drag sekarang langsung lewat frame
-- Main itu sendiri (Main.Active = true di atas biar bisa
-- nangkep input).
--==========================================================

local dragging = false
local dragStart = nil
local startPos = nil


Main.InputBegan:Connect(
    function(input)

        if
            input.UserInputType ==
                Enum.UserInputType.MouseButton1
            or
            input.UserInputType ==
                Enum.UserInputType.Touch
        then

            dragging = true

            dragStart =
                input.Position

            startPos =
                Main.Position

        end

    end
)


Main.InputEnded:Connect(
    function(input)

        if
            input.UserInputType ==
                Enum.UserInputType.MouseButton1
            or
            input.UserInputType ==
                Enum.UserInputType.Touch
        then

            dragging = false

        end

    end
)


UserInputService.InputChanged:Connect(
    function(input)

        if not dragging then
            return
        end


        if
            input.UserInputType ~=
                Enum.UserInputType.MouseMovement
            and
            input.UserInputType ~=
                Enum.UserInputType.Touch
        then

            return

        end


        local delta =
            input.Position -
            dragStart


        Main.Position =
            UDim2.new(

                startPos.X.Scale,

                startPos.X.Offset +
                    delta.X,

                startPos.Y.Scale,

                startPos.Y.Offset +
                    delta.Y

            )

    end
)


--==========================================================
-- MAIN AUTO LOOP
--==========================================================

task.spawn(function()

    --==================================================
    -- TUNGGU SAMPAI TOMBOL AUTO DI-ON-IN
    --
    -- Auto-quest baru mulai jalan SETELAH tombol AUTO
    -- ON/OFF di-klik ON pertama kali (yang otomatis
    -- ngejalanin deleteBackpack -> clearMap -> set
    -- getgenv().MerdekaMapCleared = true). Sebelum itu,
    -- GUI quest udah kebentuk & siap tapi loop-nya
    -- nunggu di sini.
    --==================================================

    while not getgenv().MerdekaMapCleared do

        if not ScreenGui.Parent then
            return
        end

        task.wait(0.5)

    end


    local cycleCount = 0


    while true do

        if not ScreenGui.Parent then
            break
        end


        if not waitForAutoOn() then
            break
        end


        cycleCount = cycleCount + 1


        Status.Text =
            "Status: Mulai siklus #" ..
            tostring(cycleCount) ..
            "..."


        local success =
            runFullCycle()


        if not ScreenGui.Parent then
            break
        end


        if success then

            Status.Text =
                "Status: Siklus #" ..
                tostring(cycleCount) ..
                " selesai! Mengulang..."

        else

            Status.Text =
                "Status: Siklus #" ..
                tostring(cycleCount) ..
                " gagal, coba lagi 5 detik lagi..."

            task.wait(5)

        end


        task.wait(1)

    end

end)

Status.Text =
    "Status: BCA Auto Loop Ready"

Status.TextColor3 =
    Color3.fromRGB(
        100,
        255,
        130
    )
