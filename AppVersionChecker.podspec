#
# Be sure to run `pod lib lint JAGiTunesStoreSearch.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "AppVersionChecker"
  s.version          = "1.0.2"
  s.summary          = "Check for the app's current version was updated latest version."
  s.description  = <<-DESC

                    Check for the app's current version was updated latest version.
                    If already updated to latest version, display the release notes from AppStore data.
                    And to request for required version from JSON file or AppStore data.

                   DESC

  s.homepage         = "https://github.com/ryuiwasaki/AppVersionChecker"
  s.license          = 'MIT'
  s.author           = { "Ryu Iwasaki" => "ryu.contact.jp@gmail.com" }
  s.source           = { :git => "https://github.com/ryuiwasaki/AppVersionChecker.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/ja_gaimopotato'

  s.platform     = :ios, '8.1'
  s.requires_arc = true

  s.source_files = 'Classes/**/*.swift'
  s.resources = 'Resources/*'

  s.dependency 'Alamofire'
end
