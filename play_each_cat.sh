#!/bin/bash

# List of available categories.
# Slow Option: Get and select from the latest categories everytime
# cats=$(for cat in "VODStudio" "VODChildren" "VODTeenagers" "VODFamily" "VODProgramsEvents" "VODOurActivities" "VODMinistry" "VODOurOrganization" "VODBible" "VODMovies" "VODSeries" "VODMusicVideos" "VODIntExp" "VODAudioDescriptions"; do curl -s "https://b.jw-cdn.org/apis/mediator/v1/categories/E/${cat}?detailed=1" | jq -r '.category.subcategories | map(.key)[]'; done && curl -s "https://b.jw-cdn.org/apis/mediator/v1/categories/E" | jq -r ".categories | map(.key)[]")
# Fast Option:
cats=(StudioFeatured StudioMonthlyPrograms StudioTalks StudioNewsReports ChildrenFeatured BJF ChildrenSongs ChildrenMovies TeenFeatured TeenSpiritualGrowth TeenSocialLife TeenGoals TeenWhatPeersSay TeenMovies FamilyFeatured FamilyChallenges FamilyDatingMarriage FamilyWorship FamilyMovies PrgEvtFeatured VODPgmEvtMorningWorship VODPgmEvtSpecial VODPgmEvtGilead VODPgmEvtAnnMtg 2022Convention 2021Convention 2020Convention 2019Convention 2018Convention 2017Convention 2016Convention 2015Convention 2014Convention ActivitiesFeatured VODActivitiesTranslation VODActivitiesAVProduction VODActivitiesPrintingShipping VODActivitiesConstruction VODActivitiesReliefWork VODActivitiesTheoSchools VODActivitiesSpecialEvents MinistryFeatured VODMinistryMidweekMeeting VODMinistryTools VODMinistryTeachings VODSampleConversations VODMinistryImproveSkills VODMinistryMethods VODMinistryExpandMinistry MeetingsConventions OrganizationFeatured Reports VODOrgBethel AccomplishMinistry VODOrgHistory VODOrgLegal VODOrgBloodlessMedicine BibleFeatured BibleBooks VODBibleTeachings VODBibleAccounts VODBibleMedia VODBibleTranslations VODBiblePrinciples VODBibleCreation MoviesFeatured VODMoviesBibleTimes VODMoviesModernDay VODMoviesExtras VODMoviesAnimated SeriesFeatured VODMinistryApplyTeaching SeriesBJFSongs SeriesBJFLessons SeriesBibleTeachings SeriesHappyMarriage SeriesBibleBooks SeriesIronSharpens SeriesWTLessons SeriesMyTeenLife SeriesOrgAccomplishments SeriesOurHistory VODPureWorshipIntro SeriesBibleChangesLives SeriesTruthTransforms SeriesOriginsLife SeriesWasItDesigned SeriesWhatPeersSay SeriesWhereAreTheyNow SeriesWhiteboard VODMusicVideosFeatured VODOriginalSongs VODSJJMeetings ChildrensSongs VODConvMusic MakingMusic VODSingToJah IntExpFeatured VODIntExpTransformations VODIntExpBlessings VODIntExpEndurance VODIntExpYouth OriginsLife VODIntExpArchives AudioDescriptionFeatured 2022ConventionAD 2021ConventionAD 2020ConventionAD)

# Get list of available languages
lang_codes=$(curl -s "https://data.jw-api.org/mediator/v1/languages/E/all" | jq -r ".languages | map(.code)[]" | tr '\n' ' ') # without `tr '\n' ' '` the script fails to work

# Prompt user to enter a valid language code
while true; do
    read -p "Please enter a language code: " lang
    lang=$(echo "$lang" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]') # convert to uppercase and remove spaces
    if [[ " ${lang_codes[@]} " =~ " ${lang} " ]]; then
        echo "You have selected the language code '$lang'."
        break
    else
        echo "The language code '$lang' is not valid. Please try again."
    fi
done

# Prompt for category
PS3="Enter the category number: "
select cat in ${cats[@]}; do
  if [[ -n $cat ]]; then
    break
  fi
done

# Get file links and play randomly via mpv ` | mpv --playlist=- --shuffle`
# Get file links and play randomly via vlc ` | vlc - --random`
# Remove `--shuffle` or `--random` to run the latest first
curl -s "https://data.jw-api.org/mediator/v1/categories/$lang/$cat" | jq | grep -Eo "https:\/\/[a-zA-Z0-9./?=_%:-]*r720P\.mp4" | vlc - --random
