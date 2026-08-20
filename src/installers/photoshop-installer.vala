public class PhotoshopInstaller : AdobeProductInstaller {
    public PhotoshopInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe Photoshop 2024"; } }
    public override string[] executable_candidates {
        owned get { return {"Photoshop.exe", "Photoshop 2024.exe"}; }
    }
}
